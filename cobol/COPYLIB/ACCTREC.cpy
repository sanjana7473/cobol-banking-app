       01  TRANSACTION-RECORD.
           05  TR-ACCOUNT-NUMBER      PIC 9(10).
           05  TR-TRANSACTION-TYPE    PIC X(01).
               88  TR-DEPOSIT         VALUE 'D'.
               88  TR-WITHDRAWAL      VALUE 'W'.
           05  TR-AMOUNT              PIC 9(07)V99.
           05  TR-DATE                PIC 9(08).
           05  TR-DESCRIPTION         PIC X(30).
           05  FILLER                 PIC X(22).

       01  ACCOUNT-RECORD.
           05  ACCT-NUMBER            PIC 9(10).
           05  ACCT-HOLDER-NAME       PIC X(30).
           05  ACCT-BALANCE           PIC 9(09)V99.
           05  ACCT-STATUS            PIC X(01).
               88  ACCT-ACTIVE        VALUE 'A'.
               88  ACCT-CLOSED        VALUE 'C'.
               88  ACCT-FROZEN        VALUE 'F'.
           05  ACCT-LAST-UPDATE       PIC 9(08).
           05  FILLER                 PIC X(20).

       01  VALIDATED-TRANSACTION-RECORD.
           05  VTR-ACCOUNT-NUMBER     PIC 9(10).
           05  VTR-TRANSACTION-TYPE   PIC X(01).
           05  VTR-AMOUNT             PIC 9(07)V99.
           05  VTR-DATE               PIC 9(08).
           05  VTR-DESCRIPTION        PIC X(30).
           05  VTR-STATUS             PIC X(01).
               88  VTR-VALID          VALUE 'V'.
               88  VTR-INVALID        VALUE 'I'.
           05  VTR-ERROR-CODE         PIC 9(02).
               88  ERR-NONE           VALUE 00.
               88  ERR-INVALID-ACCT   VALUE 01.
               88  ERR-INVALID-TYPE   VALUE 02.
               88  ERR-INVALID-AMT    VALUE 03.
               88  ERR-ACCT-CLOSED    VALUE 04.
               88  ERR-ACCT-FROZEN    VALUE 05.
               88  ERR-INSUFF-FUNDS   VALUE 06.
           05  FILLER                 PIC X(19).
