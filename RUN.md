# Run It Yourself — Steps

## 1. Get the code

```bash
git clone https://github.com/sanjana7473/cobol-banking-app.git   # clone repo
cd cobol-banking-app                                              # enter folder
```

## 2. Install tools

```bash
sudo apt install -y docker.io wget unzip curl python3              # prerequisites
```

## 3. Install TK5 (MVS 3.8j)

```bash
bash setup_tk5.sh                                                 # download + extract → hercules/tk5/
```

## 4. Boot TK5

```bash
cd hercules/tk5
export LD_LIBRARY_PATH="$PWD/hercules/linux/64/lib:$PWD/hercules/linux/64/lib/hercules"   # hercules libs
tail -f /dev/null | ./hercules/linux/64/bin/hercules -f conf/tk5.cnf -r scripts/ipl.rc > log/3033.log 2>&1 &   # start in background
cd ../..
sleep 90                                                          # wait for IPL
curl -s "http://127.0.0.1:8038/cgi-bin/tasks/syslog?msgcount=0" | grep -a 'HASP000 OK'    # must print: $HASP000 OK
```

## 5. Start FTP server + watcher

```bash
docker run -d --name pure-ftpd \
  -p 2121:21 -p 30000-30009:30000-30009 \
  -e FTP_USER_NAME=herc01 -e FTP_USER_PASS=cul8tr \
  -e FTP_USER_HOME=/home/ftpusers/herc01 \
  -e PUBLICHOST=127.0.0.1 \
  -v "$PWD/hercules/tk5/rdr:/home/ftpusers/herc01" \
  stilliard/pure-ftpd:latest                                      # FTP server (uploads land in rdr/)
bash tk5-ftp-watcher.sh &                                          # auto-submit uploaded JCL to JES2
```

## 6. Run once (sanity check)

```bash
bash run-all.sh                                                   # reset → compile → BANKRUN; expect balance $689,200.00
```

## 7. Run the tests

```bash
python3 ci/unit-test.py                                           # 12 checks (layouts, 6 validation codes, golden)
bash ci/integration-test.sh                                       # BANKRUN vs golden diff (needs compiled programs)
```

## 8. Benchmark — 14× local

```bash
bash ci/run-benchmark.sh A localhost                              # 14 runs → results/env-a/
```

## 9. Benchmark — 14× Oracle VM (optional)

```bash
bash ci/run-benchmark.sh B <oracle-vm-ip> ubuntu                  # needs TK5+FTP+watcher on the VM too
```

## 10. Compare

```bash
python3 ci/compare-benchmarks.py                                  # → results/comparison.md
cat results/comparison.md                                          # read the verdict
```

## Stop

```bash
docker stop pure-ftpd                                             # stop FTP server
pkill -f 'hercules/linux/64/bin/hercules'                         # stop TK5
```
