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
		

		

		
IF OBJECT_ID('aktualne_rezerwacje', 'V') IS NOT NULL 
    DROP VIEW aktualne_rezerwacje;
CREATE VIEW aktualne_rezerwacje(id_rezerwacji, data_przyjazdu, data_wyjazdu, liczba_osob, gosc, pokoj, przedluzenie)
AS
(
    SELECT  id_rezerwacji,
			data_przyjazdu,
			data_wyjazdu,
			liczba_osob,
			gosc,
			pokoj,
			przedluzenie
    FROM    rezerwacja
    WHERE   status = 'zrealizowana' AND ((GETDATE() BETWEEN data_przyjazdu AND data_wyjazdu) OR (GETDATE() BETWEEN data_przyjazdu AND przedluzenie))
);




IF OBJECT_ID('nowa_rezerwacja', 'P') IS NOT NULL 
    DROP PROCEDURE nowa_rezerwacja;

CREATE PROCEDURE nowa_rezerwacja @data_rezerwacji  DATE,
                           @data_przyjazdu DATE,
						   @data_wyjazdu DATE,
						   @liczba_osob INT,
						   @status VARCHAR(30) = 'oczekujaca',
						   @wyzywienie VARCHAR(30) = NULL,
						   @gosc VARCHAR(11),
						   @pokoj INT
AS
    BEGIN TRY
	IF NOT EXISTS (SELECT *
					FROM pokoj
					WHERE nr_pokoju = @pokoj)
					BEGIN
					RAISERROR('Bledny nr pokoju', 11, 1)
					END
	IF NOT EXISTS (SELECT *
					FROM gosc
					WHERE pesel = @gosc)
					BEGIN
					RAISERROR('Goscia nie ma w bazie', 11, 1)
					END
	IF EXISTS (SELECT *
			   FROM rezerwacja
		       WHERE pokoj = @pokoj AND ((data_przyjazdu <= @data_przyjazdu AND data_wyjazdu >= @data_przyjazdu) OR (data_przyjazdu <= @data_wyjazdu AND data_wyjazdu >= @data_wyjazdu) OR (data_przyjazdu >= @data_przyjazdu AND data_wyjazdu <= @data_wyjazdu)))
			   BEGIN
			   RAISERROR('W wybranym terminie pokoj jest zajety', 11, 1)
			   END
	IF @liczba_osob > (SELECT S.max_liczba_osob
						FROM pokoj P
						INNER JOIN standard S
						ON P.standard = S.id_standardu
						WHERE P.nr_pokoju = @pokoj)
						BEGIN
						RAISERROR('Przekroczono limit osob w pokoju', 11, 1)
						END
	IF (DATEDIFF(dd, @data_przyjazdu, @data_wyjazdu) < (SELECT S.min_czas_pobytu
														FROM pokoj P
														INNER JOIN standard S
														ON P.standard = S.id_standardu
														WHERE P.nr_pokoju = @pokoj)
		OR
		DATEDIFF(dd, @data_przyjazdu, @data_wyjazdu) > (SELECT S.max_czas_pobytu
														FROM pokoj P
														INNER JOIN standard S
														ON P.standard = S.id_standardu
														WHERE P.nr_pokoju = @pokoj))
		BEGIN
		RAISERROR('Zbyt dlugi lub zbyt krotki czas pobytu', 11, 1)
		END

	IF @data_rezerwacji IS NULL SET @data_rezerwacji = GETDATE()

	INSERT INTO rezerwacja (data_rezerwacji, data_przyjazdu, data_wyjazdu, liczba_osob, status, wyzywienie, gosc, pokoj)
	VALUES (@data_rezerwacji, @data_przyjazdu, @data_wyjazdu, @liczba_osob, @status, @wyzywienie, @gosc, @pokoj)


	END TRY
	BEGIN CATCH
	SELECT ERROR_NUMBER() AS 'NUMER BLEDU',
           ERROR_MESSAGE() AS 'KOMUNIKAT'
	END CATCH;
	
	
	
	
IF OBJECT_ID('dodaj_goscia', 'P') IS NOT NULL 
    DROP PROCEDURE dodaj_goscia;
CREATE PROCEDURE dodaj_goscia @pesel VARCHAR(11),
							  @imie VARCHAR(30) = NULL,
							  @nazwisko VARCHAR(30),
							  @data_urodzenia DATE
AS
	BEGIN TRY
	INSERT INTO gosc (pesel, imie, nazwisko, data_urodzenia)
	VALUES (@pesel, @imie, @nazwisko, @data_urodzenia)
	END TRY
	BEGIN CATCH
	SELECT ERROR_NUMBER() AS 'NUMER BLEDU',
           ERROR_MESSAGE() AS 'KOMUNIKAT'
	END CATCH
	

	
IF OBJECT_ID('usun_rezerwacje', 'P') IS NOT NULL 
    DROP PROCEDURE usun_rezerwacje;
CREATE PROCEDURE usun_rezerwacje @id_rezerwacji INT
AS
	BEGIN TRY
	DELETE FROM rezerwacja
	WHERE id_rezerwacji = @id_rezerwacji
	END TRY
	BEGIN CATCH
	SELECT ERROR_NUMBER() AS 'NUMER BLEDU',
           ERROR_MESSAGE() AS 'KOMUNIKAT'
	END CATCH
	
	
	
	

IF OBJECT_ID('przedluz_rezerwacje', 'P') IS NOT NULL 
    DROP PROCEDURE przedluz_rezerwacje;
CREATE PROCEDURE przedluz_rezerwacje @id_rezerwacji INT,
									@przedluzenie DATE
AS
	BEGIN TRY
	IF (SELECT przedluzenie
		FROM rezerwacja
		WHERE id_rezerwacji = @id_rezerwacji) IS NOT NULL
		BEGIN
		RAISERROR('Mozna dokonac tylko jednego predluzenia dla danej rezerwacji', 11, 1)
		END
	UPDATE rezerwacja
	SET przedluzenie = @przedluzenie
	WHERE id_rezerwacji = @id_rezerwacji
	END TRY
	BEGIN CATCH
	SELECT ERROR_NUMBER() AS 'NUMER BLEDU',
           ERROR_MESSAGE() AS 'KOMUNIKAT'
	END CATCH
	
	
	

IF OBJECT_ID('wygeneruj_rachunek', 'P') IS NOT NULL 
    DROP PROCEDURE wygeneruj_rachunek;
CREATE PROCEDURE wygeneruj_rachunek @id_rezerwacji INT,
									@suma INT OUTPUT
AS
	DECLARE @liczba_dni INT
	DECLARE @zakwaterowanie INT
	DECLARE @wyzywienie INT
	DECLARE @spa INT
	DECLARE @sezon FLOAT
	BEGIN TRY
	SET @liczba_dni = (SELECT DATEDIFF(dd, data_przyjazdu, data_wyjazdu) + DATEDIFF(dd, data_wyjazdu, ISNULL(przedluzenie, data_wyjazdu))
						FROM rezerwacja
						WHERE id_rezerwacji = @id_rezerwacji)
	SET @sezon = (SELECT procent_ceny_standardowej
					FROM rezerwacja R
					INNER JOIN sezon S
					ON R.data_przyjazdu BETWEEN S.dat_rozpoczecia AND S.data_zakonczenia
					WHERE R.id_rezerwacji = @id_rezerwacji)
	SET @zakwaterowanie = (SELECT S.cena_za_dobe * @sezon * @liczba_dni
							FROM rezerwacja R
							INNER JOIN pokoj P
							ON R.pokoj = P.nr_pokoju
							INNER JOIN standard S
							ON P.standard = S.id_standardu
							WHERE R.id_rezerwacji = @id_rezerwacji)
	SET @wyzywienie = (SELECT W.cena_za_osobe_doba * @liczba_dni
						FROM rezerwacja R
						INNER JOIN wyzywienie W
						ON R.wyzywienie = W.id_pakietu
						WHERE R.id_rezerwacji = @id_rezerwacji)
	SET @spa = (SELECT SUM(RS.liczba_osob*ZS.cena_za_osobe)
				FROM rachunek_spa RS
				INNER JOIN zabieg_spa ZS
				ON RS.zabieg = ZS.id_zabiegu
				WHERE RS.rezerwacja = @id_rezerwacji)
	SET @suma = @zakwaterowanie + @wyzywienie + @spa
						 
	END TRY
	BEGIN CATCH
	SELECT ERROR_NUMBER() AS 'NUMER BLEDU',
           ERROR_MESSAGE() AS 'KOMUNIKAT'
	END CATCH
	
	

	
	
CREATE FUNCTION liczba_zabiegow
(
	@id_rezerwacji INT
)
    RETURNS INT
AS
BEGIN
	DECLARE @liczba_zabiegow INT
	SET @liczba_zabiegow = (SELECT COUNT(*)
							FROM rachunek_spa
							WHERE rezerwacja = @id_rezerwacji)
    RETURN @liczba_zabiegow
END;







CREATE FUNCTION grafik_rezerwacji_pokoju
(
    @pokoj INT
)
    RETURNS @grafik TABLE(id_rezerwacji INT, data_przyjazdu DATE, data_wyjazdu DATE, przedluzenie DATE, status VARCHAR(30))
AS
BEGIN
	INSERT INTO @grafik
	SELECT id_rezerwacji,
			data_przyjazdu,
			data_wyjazdu,
			przedluzenie,
			status
	FROM rezerwacja
	WHERE pokoj = @pokoj
	ORDER BY data_przyjazdu
	RETURN;
END;




CREATE TRIGGER pokoj_niedostepny ON pokoj
INSTEAD OF DELETE
AS
BEGIN
	UPDATE pokoj
	SET zajety = 1
	WHERE nr_pokoju = (SELECT nr_pokoju FROM deleted)
END;







CREATE TRIGGER zmiana_ceny ON sezon
AFTER UPDATE
AS
BEGIN
	BEGIN TRANSACTION
	IF ((SELECT procent_ceny_standardowej FROM inserted) > 1.5)
	BEGIN
	PRINT 'Cena sezonowa nie moze byc wyzsza o wiecej niz 50% od ceny standardowej'
	ROLLBACK TRANSACTION
	END
	ELSE
	COMMIT TRANSACTION
END;





