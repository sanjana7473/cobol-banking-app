c3270 localhost:3270


curl -T /tmp/00_delete.jcl ftp://localhost:2121/ --user herc01:cul8tr


curl -T /tmp/01_alloc.jcl ftp://localhost:2121/ --user herc01:cul8tr
sleep 4

curl -T /tmp/02_valdcomp.jcl ftp://localhost:2121/ --user herc01:cul8tr
sleep 5

curl -T /tmp/03_updtcomp.jcl ftp://localhost:2121/ --user herc01:cul8tr
sleep 5

curl -T /tmp/04_rprtcomp.jcl ftp://localhost:2121/ --user herc01:cul8tr
sleep 10

curl -T /tmp/05_bankrun.jcl ftp://localhost:2121/ --user herc01:cul8tr

curl -T file.jcl ftp://localhost:2121/ --user herc01:cul8tr