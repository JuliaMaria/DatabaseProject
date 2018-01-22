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

SELECT * FROM aktualne_rezerwacje;


IF OBJECT_ID('nowa_rezerwacja', 'P') IS NOT NULL 
    DROP PROCEDURE nowa_rezerwacja;
CREATE PROCEDURE nowa_rezerwacja @data_rezerwacji  DATE,
                           @data_przyjazdu DATE,
						   @data_wyjazdu DATE,
						   @liczba_osob INT,
						   @status VARCHAR(30) = 'oczekujaca',
						   @wyzywienie INT = NULL,
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
	IF (SELECT zajety
		FROM pokoj
		WHERE nr_pokoju = @pokoj) = 1
		BEGIN
		RAISERROR('Pokoj jest niedostepny', 11, 1)
		END
	IF EXISTS (SELECT *
			   FROM rezerwacja
		       WHERE pokoj = @pokoj AND ((data_przyjazdu <= @data_przyjazdu AND ISNULL(przedluzenie, data_wyjazdu) >= @data_przyjazdu) OR (data_przyjazdu <= @data_wyjazdu AND ISNULL(przedluzenie, data_wyjazdu) >= @data_wyjazdu) OR (data_przyjazdu >= @data_przyjazdu AND ISNULL(przedluzenie, data_wyjazdu) <= @data_wyjazdu)))
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
	DECLARE @sezon INT
	SET @sezon = (SELECT id_sezonu
					FROM sezon
					WHERE @data_przyjazdu BETWEEN dat_rozpoczecia AND data_zakonczenia)

	INSERT INTO rezerwacja (data_rezerwacji, data_przyjazdu, data_wyjazdu, liczba_osob, status, wyzywienie, gosc, pokoj, sezon)
	VALUES (@data_rezerwacji, @data_przyjazdu, @data_wyjazdu, @liczba_osob, @status, @wyzywienie, @gosc, @pokoj, @sezon)


	END TRY
	BEGIN CATCH
	SELECT ERROR_NUMBER() AS 'NUMER BLEDU',
           ERROR_MESSAGE() AS 'KOMUNIKAT'
	END CATCH;
	
EXEC nowa_rezerwacja '2018-01-20', '2018-01-25', '2018-01-30', 2, 'oczekujaca', 1, '89765467890', 2;
EXEC nowa_rezerwacja '2018-01-20', '2018-01-22', '2018-01-29', 1, 'oczekujaca', 2, '97095645789', 3;
	
		
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
	END CATCH;
	
EXEC dodaj_goscia '09878967856', 'Kamil', 'Malkowski', '1995-02-23';
	
	
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
	END CATCH;
	
EXEC usun_rezerwacje 1;
	
	
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
	END CATCH;
	
EXEC przedluz_rezerwacje 2, '2018-02-02';
	

IF OBJECT_ID('wygeneruj_rachunek', 'P') IS NOT NULL 
    DROP PROCEDURE wygeneruj_rachunek;
CREATE PROCEDURE wygeneruj_rachunek @id_rezerwacji INT
AS
	DECLARE @suma INT
	DECLARE @liczba_dni INT
	DECLARE @zakwaterowanie INT
	DECLARE @wyzywienie INT
	DECLARE @spa INT
	DECLARE @sezon FLOAT
	BEGIN TRY
	SET @liczba_dni = (SELECT DATEDIFF(dd, data_przyjazdu, data_wyjazdu) + DATEDIFF(dd, data_wyjazdu, ISNULL(przedluzenie, data_wyjazdu))
						FROM rezerwacja
						WHERE id_rezerwacji = @id_rezerwacji)
	SET @liczba_dni = @liczba_dni + 1
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
	PRINT 'Zakwaterowanie: '
	PRINT @zakwaterowanie
	SET @wyzywienie = (SELECT W.cena_za_osobe_doba * @liczba_dni
						FROM rezerwacja R
						INNER JOIN wyzywienie W
						ON R.wyzywienie = W.id_pakietu
						WHERE R.id_rezerwacji = @id_rezerwacji)
	PRINT 'Wyzywienie: '
	PRINT @wyzywienie
	SET @spa = ISNULL((SELECT SUM(RS.liczba_osob*ZS.cena_za_osobe)
				FROM rachunek_spa RS
				INNER JOIN zabieg_spa ZS
				ON RS.zabieg = ZS.id_zabiegu
				WHERE RS.rezerwacja = @id_rezerwacji), 0)
	PRINT 'SPA: '
	PRINT @spa
	SET @suma = @zakwaterowanie + @wyzywienie + @spa
	PRINT 'Suma: '
	PRINT @suma					 
	END TRY
	BEGIN CATCH
	SELECT ERROR_NUMBER() AS 'NUMER BLEDU',
           ERROR_MESSAGE() AS 'KOMUNIKAT'
	END CATCH;
	
EXEC wygeneruj_rachunek 2;
		
	
IF OBJECT_ID('liczba_zabiegow', 'FN') IS NOT NULL 
    DROP FUNCTION liczba_zabiegow;
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

DECLARE @zabiegi INT;
EXEC @zabiegi = dbo.liczba_zabiegow 2;
PRINT @zabiegi;


IF OBJECT_ID('grafik_rezerwacji_pokoju', 'TF') IS NOT NULL 
    DROP FUNCTION grafik_rezerwacji_pokoju;
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

SELECT * FROM dbo.grafik_rezerwacji_pokoju(2);


IF OBJECT_ID('pokoj_niedostepny', 'T') IS NOT NULL 
    DROP TRIGGER pokoj_niedostepny;
CREATE TRIGGER pokoj_niedostepny ON pokoj
INSTEAD OF DELETE
AS
BEGIN
	UPDATE pokoj
	SET zajety = 1
	WHERE nr_pokoju = (SELECT nr_pokoju FROM deleted)
END;

DELETE FROM pokoj
WHERE nr_pokoju = 1;


IF OBJECT_ID('zmiana_ceny', 'T') IS NOT NULL 
    DROP TRIGGER zmiana_ceny;
CREATE TRIGGER zmiana_ceny ON sezon
AFTER UPDATE
AS
BEGIN
	IF(UPDATE(procent_ceny_standardowej))
	BEGIN
	BEGIN TRANSACTION
	IF ((SELECT procent_ceny_standardowej FROM inserted) > 1.5)
	BEGIN
	PRINT 'Cena sezonowa nie moze byc wyzsza o wiecej niz 50% od ceny standardowej'
	ROLLBACK TRANSACTION
	END
	ELSE
	COMMIT TRANSACTION
	END
END;

UPDATE sezon
SET procent_ceny_standardowej = 2
WHERE id_sezonu = 2;
