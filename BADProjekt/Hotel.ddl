IF OBJECT_ID('gosc', 'U') IS NOT NULL 
    DROP TABLE gosc;

CREATE TABLE gosc (
    pesel            VARCHAR(11) NOT NULL CHECK (pesel LIKE '[0-9]%'),
    imie             VARCHAR(30),
    nazwisko         VARCHAR(30) NOT NULL,
    data_urodzenia   DATE NOT NULL
);

ALTER TABLE gosc ADD CONSTRAINT gosc_pk PRIMARY KEY ( pesel );


IF OBJECT_ID('pokoj', 'U') IS NOT NULL 
    DROP TABLE pokoj;
CREATE TABLE pokoj (
    nr_pokoju   INTEGER NOT NULL CHECK (nr_pokoju > 0),
    zajety      CHAR(1) NOT NULL DEFAULT 0,
    standard    INTEGER
);

ALTER TABLE pokoj ADD CONSTRAINT pokoj_pk PRIMARY KEY ( nr_pokoju );


IF OBJECT_ID('rachunek_spa', 'U') IS NOT NULL 
    DROP TABLE rachunek_spa;
CREATE TABLE rachunek_spa (
    id_uslugi      INTEGER NOT NULL IDENTITY(1,1),
    data_zabiegu   DATE NOT NULL,
    liczba_osob    INTEGER NOT NULL,
    zabieg         INTEGER,
    rezerwacja     INTEGER
);

ALTER TABLE rachunek_spa ADD CONSTRAINT rachunek_spa_pk PRIMARY KEY ( id_uslugi );


IF OBJECT_ID('rezerwacja', 'U') IS NOT NULL 
    DROP TABLE rezerwacja;
CREATE TABLE rezerwacja (
    id_rezerwacji     INTEGER NOT NULL IDENTITY(1,1),
    data_rezerwacji   DATE NOT NULL,
    data_przyjazdu    DATE NOT NULL,
    data_wyjazdu      DATE NOT NULL,
    liczba_osob       INTEGER NOT NULL,
    status            VARCHAR(30) NOT NULL CHECK (status IN ('oczekujaca', 'zrealizowana', 'odwolana')) DEFAULT 'oczekujaca',
    przedluzenie      DATE,
    wyzywienie        INTEGER,
    gosc              VARCHAR(11),
    pokoj             INTEGER,
    sezon             INTEGER,
	CHECK (data_wyjazdu > data_przyjazdu),
	CHECK (przedluzenie > data_wyjazdu)
);

ALTER TABLE rezerwacja ADD CONSTRAINT rezerwacja_pk PRIMARY KEY ( id_rezerwacji );


IF OBJECT_ID('sezon', 'U') IS NOT NULL 
    DROP TABLE sezon;
CREATE TABLE sezon (
    id_sezonu                   INTEGER NOT NULL IDENTITY(1,1),
    nazwa                       VARCHAR(30) NOT NULL,
    dat_rozpoczecia             DATE NOT NULL,
    data_zakonczenia            DATE NOT NULL,
    procent_ceny_standardowej   FLOAT NOT NULL,
	CHECK (data_zakonczenia > dat_rozpoczecia)
);

ALTER TABLE sezon ADD CONSTRAINT sezon_pk PRIMARY KEY ( id_sezonu );


IF OBJECT_ID('standard', 'U') IS NOT NULL 
    DROP TABLE standard;
CREATE TABLE standard (
    id_standardu      INTEGER NOT NULL IDENTITY(1,1),
    nazwa             VARCHAR(30) NOT NULL,
    cena_za_dobe      MONEY NOT NULL,
    max_liczba_osob   INTEGER NOT NULL,
    min_czas_pobytu   INTEGER NOT NULL,
    max_czas_pobytu   INTEGER NOT NULL
);

ALTER TABLE standard ADD CONSTRAINT standard_pk PRIMARY KEY ( id_standardu );


IF OBJECT_ID('wyzywienie', 'U') IS NOT NULL 
    DROP TABLE wyzywienie;
CREATE TABLE wyzywienie (
    id_pakietu           INTEGER NOT NULL IDENTITY(1,1),
    nazwa                VARCHAR(30) NOT NULL,
    cena_za_osobe_doba   MONEY NOT NULL
);

ALTER TABLE wyzywienie ADD CONSTRAINT wyzywienie_pk PRIMARY KEY ( id_pakietu );


IF OBJECT_ID('zabieg_spa', 'U') IS NOT NULL 
    DROP TABLE zabieg_spa;
CREATE TABLE zabieg_spa (
    id_zabiegu      INTEGER NOT NULL IDENTITY(1,1),
    nazwa           VARCHAR(30) NOT NULL,
    cena_za_osobe   MONEY NOT NULL
);

ALTER TABLE zabieg_spa ADD CONSTRAINT zabieg_spa_pk PRIMARY KEY ( id_zabiegu );


ALTER TABLE pokoj
    ADD CONSTRAINT pokoj_standard_fk FOREIGN KEY ( standard )
        REFERENCES standard ( id_standardu );

ALTER TABLE rachunek_spa
    ADD CONSTRAINT rachunek_spa_rezerwacja_fk FOREIGN KEY ( rezerwacja )
        REFERENCES rezerwacja ( id_rezerwacji );

ALTER TABLE rachunek_spa
    ADD CONSTRAINT rachunek_spa_zabieg_spa_fk FOREIGN KEY ( zabieg )
        REFERENCES zabieg_spa ( id_zabiegu );

ALTER TABLE rezerwacja
    ADD CONSTRAINT rezerwacja_gosc_fk FOREIGN KEY ( gosc )
        REFERENCES gosc ( pesel );

ALTER TABLE rezerwacja
    ADD CONSTRAINT rezerwacja_pokoj_fk FOREIGN KEY ( pokoj )
        REFERENCES pokoj ( nr_pokoju );

ALTER TABLE rezerwacja
    ADD CONSTRAINT rezerwacja_sezon_fk FOREIGN KEY ( sezon )
        REFERENCES sezon ( id_sezonu );

ALTER TABLE rezerwacja
    ADD CONSTRAINT rezerwacja_wyzywienie_fk FOREIGN KEY ( wyzywienie )
        REFERENCES wyzywienie ( id_pakietu );