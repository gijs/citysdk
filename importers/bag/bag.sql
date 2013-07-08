----------------------------------------------------------------------------------------
-- SQL script to create useful BAG data for CitySDK.
-- Expects BAG to already be imported in PostgreSQL.
----------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------
--    Tabellen met indices voor status/gebruiksdoel:    --------------------------------
----------------------------------------------------------------------------------------

CREATE TABLE citysdk.pandstatus (
  id serial NOT NULL,
  status text,
  CONSTRAINT pandstatus_pkey PRIMARY KEY (id)
);

INSERT INTO citysdk.pandstatus (status)
  SELECT DISTINCT pandstatus FROM pandactueelbestaand;
 
CREATE TABLE citysdk.ligplaatsstatus (
  id serial NOT NULL,
  status text,
  CONSTRAINT ligplaatsstatus_pkey PRIMARY KEY (id)
);

INSERT INTO citysdk.ligplaatsstatus (status)
  SELECT DISTINCT ligplaatsstatus FROM ligplaatsactueelbestaand;
  
CREATE TABLE citysdk.standplaatsstatus (
  id serial NOT NULL,
  status text,
  CONSTRAINT standplaatsstatus_pkey PRIMARY KEY (id)
);

INSERT INTO citysdk.standplaatsstatus (status)
  SELECT DISTINCT standplaatsstatus FROM standplaatsactueelbestaand;
 
CREATE TABLE citysdk.verblijfsobjectstatus (
  id serial NOT NULL,
  status text,
  CONSTRAINT verblijfsobjectstatus_pkey PRIMARY KEY (id)
);

INSERT INTO citysdk.verblijfsobjectstatus (status)
  SELECT DISTINCT verblijfsobjectstatus FROM verblijfsobjectactueelbestaand;

CREATE TABLE citysdk.gebruiksdoel (
  id serial NOT NULL,
  gebruiksdoel text,
  CONSTRAINT gebruiksdoel_pkey PRIMARY KEY (id)
);

INSERT INTO citysdk.gebruiksdoel (gebruiksdoel)
  SELECT DISTINCT gebruiksdoelverblijfsobject FROM verblijfsobjectgebruiksdoelactueel;

----------------------------------------------------------------------------------------
--    Functies om adressen en toevoegingen samen te voegen:    -------------------------
----------------------------------------------------------------------------------------

DROP FUNCTION IF EXISTS citysdk.adres(openbareruimtenaam text, huisnummer integer, huisletter text, huisnummertoevoeging text);
CREATE OR REPLACE FUNCTION citysdk.adres(openbareruimtenaam text, huisnummer integer, huisletter text, huisnummertoevoeging text) 
RETURNS text
AS $$
DECLARE
  _adres text;
BEGIN
  _adres := openbareruimtenaam;
  IF huisnummer IS NOT NULL THEN
    _adres := _adres || ' ' || huisnummer;
    IF huisletter IS NOT NULL THEN
      _adres := _adres || ' ' || huisletter;
    END IF;
    IF huisnummertoevoeging IS NOT NULL THEN
      _adres := _adres || ' ' || huisnummertoevoeging;
    END IF;    
  END IF;
  RETURN _adres;
END $$ LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS citysdk.adres_pc_woonplaats(adres text, postcode text, woonplaats text);
CREATE OR REPLACE FUNCTION citysdk.adres_pc_woonplaats(adres text, postcode text, woonplaats text) 
RETURNS text
AS $$
BEGIN
  RETURN adres || ', ' || postcode || ', ' || woonplaats;
END $$ LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS citysdk.nummer_letter_toevoeging(nummer int, letter text, toevoeging text);
CREATE OR REPLACE FUNCTION citysdk.nummer_letter_toevoeging(nummer int, letter text, toevoeging text) 
RETURNS text
AS $$
DECLARE
  _nummer_letter_toevoeging text;
BEGIN
  _nummer_letter_toevoeging := '' || nummer;
  IF letter IS NOT NULL THEN
    _nummer_letter_toevoeging := _nummer_letter_toevoeging || letter;
    IF toevoeging IS NOT NULL THEN
      _nummer_letter_toevoeging := _nummer_letter_toevoeging || toevoeging;
    END IF;
  END IF;
  RETURN lower(_nummer_letter_toevoeging);
END $$ LANGUAGE plpgsql IMMUTABLE;

----------------------------------------------------------------------------------------
--    Panden:    -----------------------------------------------------------------------
----------------------------------------------------------------------------------------

CREATE VIEW citysdk.pand AS
  SELECT DISTINCT ON (identificatie)
    identificatie::bigint AS pand_id, 
    pandstatus::text AS status,
    --(SELECT id FROM citysdk.pandstatus WHERE status = p.pandstatus::text) AS pandstatus_id, 
    bouwjaar::int, 
    ST_Transform(ST_Force_2D(geovlak), 4326) AS geom 
  FROM pandactueelbestaand p;

----------------------------------------------------------------------------------------
--    Verblijfsobjecten:    ------------------------------------------------------------
----------------------------------------------------------------------------------------
    
CREATE VIEW citysdk.verblijfsobject AS  
  SELECT DISTINCT ON (vbo.identificatie)
    vbo.identificatie::bigint AS vbo_id,
    (
    	SELECT 
    	array_to_string(array_agg(p.identificatie::bigint), ',') AS pand_ids
    	FROM pandactueelbestaand p
    	JOIN verblijfsobjectpandactueel vbop
    	ON p.identificatie = vbop.gerelateerdpand
    	WHERE vbop.identificatie = vbo.identificatie
    ),
    verblijfsobjectstatus::text AS status, 
    gebruiksdoelverblijfsobject::text AS gebruiksdoel,
    --(SELECT id FROM citysdk.verblijfsobjectstatus WHERE status = verblijfsobjectstatus::text) AS verblijfsobjectstatus_id, 
    --(SELECT id FROM citysdk.gebruiksdoel g WHERE g.gebruiksdoel = gebruiksdoelverblijfsobject::text) AS gebruiksdoel_id,
    oppervlakteverblijfsobject::int AS oppervlakte,
    openbareruimtenaam::text AS straat,
    huisnummer::int,
    huisletter::text,
    huisnummertoevoeging::text AS toevoeging,
    citysdk.nummer_letter_toevoeging(huisnummer::int, huisletter, huisnummertoevoeging) AS nummer_letter_toevoeging,
    citysdk.adres(openbareruimtenaam, huisnummer::int, huisletter, huisnummertoevoeging),
    postcode::text,
    lower(postcode || citysdk.nummer_letter_toevoeging(huisnummer::int, huisletter, huisnummertoevoeging)) AS postcode_huisnummer,
    woonplaatsnaam::text AS woonplaats,
    ST_Transform(ST_Force_2D(geopunt), 4326) AS geom
  FROM verblijfsobjectactueelbestaand vbo
  JOIN verblijfsobjectgebruiksdoelactueel gd
  ON gd.identificatie = vbo.identificatie
  JOIN nummeraanduidingactueelbestaand na
  ON na.identificatie = vbo.hoofdadres
  JOIN openbareruimteactueelbestaand opr
  ON na.gerelateerdeopenbareruimte = opr.identificatie
  JOIN woonplaatsactueelbestaand wp
  ON opr.gerelateerdewoonplaats = wp.identificatie;

----------------------------------------------------------------------------------------
--    Ligplaatsen:    ------------------------------------------------------------------
----------------------------------------------------------------------------------------

CREATE VIEW citysdk.ligplaats AS  
  SELECT DISTINCT ON (lp.identificatie)
    lp.identificatie::bigint AS ligplaats_id,
    ligplaatsstatus::text AS status,
    --(SELECT id FROM citysdk.ligplaatsstatus WHERE status = ligplaatsstatus::text) AS ligplaatsstatus_id,   
    openbareruimtenaam::text AS straat,
    huisnummer::int,
    huisletter::text,
    huisnummertoevoeging::text AS toevoeging,
    citysdk.nummer_letter_toevoeging(huisnummer::int, huisletter, huisnummertoevoeging) AS nummer_letter_toevoeging,
    citysdk.adres(openbareruimtenaam, huisnummer::int, huisletter, huisnummertoevoeging),
    postcode::text,
    lower(postcode || citysdk.nummer_letter_toevoeging(huisnummer::int, huisletter, huisnummertoevoeging)) AS postcode_huisnummer,
    woonplaatsnaam::text AS woonplaats,
    ST_Transform(ST_Force_2D(lp.geovlak), 4326) AS geom
  FROM ligplaatsactueelbestaand lp
  JOIN nummeraanduidingactueelbestaand na
  ON na.identificatie = lp.hoofdadres
  JOIN openbareruimteactueelbestaand opr
  ON na.gerelateerdeopenbareruimte = opr.identificatie
  JOIN woonplaatsactueelbestaand wp
  ON opr.gerelateerdewoonplaats = wp.identificatie;

----------------------------------------------------------------------------------------
--    Standplaatsen:    ----------------------------------------------------------------
----------------------------------------------------------------------------------------

CREATE VIEW citysdk.standplaats AS  
  SELECT DISTINCT ON (sp.identificatie)
    sp.identificatie::bigint AS standplaats_id,
    standplaatsstatus::text AS status,
    --(SELECT id FROM citysdk.standplaatsstatus WHERE status = standplaatsstatus::text) AS standplaatsstatus_id,   
    openbareruimtenaam::text AS straat,
    huisnummer::int,
    huisletter::text,
    huisnummertoevoeging::text AS toevoeging,
    citysdk.nummer_letter_toevoeging(huisnummer::int, huisletter, huisnummertoevoeging) AS nummer_letter_toevoeging,
    citysdk.adres(openbareruimtenaam, huisnummer::int, huisletter, huisnummertoevoeging),
    postcode::text,
    lower(postcode || citysdk.nummer_letter_toevoeging(huisnummer::int, huisletter, huisnummertoevoeging)) AS postcode_huisnummer,
    woonplaatsnaam::text AS woonplaats,
    ST_Transform(ST_Force_2D(sp.geovlak), 4326) AS geom
  FROM standplaatsactueelbestaand sp
  JOIN nummeraanduidingactueelbestaand na
  ON na.identificatie = sp.hoofdadres
  JOIN openbareruimteactueelbestaand opr
  ON na.gerelateerdeopenbareruimte = opr.identificatie
  JOIN woonplaatsactueelbestaand wp
  ON opr.gerelateerdewoonplaats = wp.identificatie;
  
----------------------------------------------------------------------------------------
--    Postcodes:    --------------------------------------------------------------------
----------------------------------------------------------------------------------------
  
CREATE TABLE citysdk.postcodes AS
  SELECT
    substring(postcode from 1 for 4) AS pc4, 
    substring(postcode from 1 for 5) AS pc5, 
    postcode::text AS pc6, 
    ST_Transform(ST_Force_2D(geopunt), 4326) AS geom
  FROM nummeraanduidingactueelbestaand na 
  JOIN verblijfsobjectactueelbestaand vbo 
  ON vbo.hoofdadres = na.identificatie
  WHERE postcode IS NOT NULL;
  
CREATE INDEX ON citysdk.postcodes
  USING btree (pc4);

CREATE INDEX ON citysdk.postcodes
  USING btree (pc5);

CREATE INDEX ON citysdk.postcodes
  USING btree (pc6);

CREATE VIEW citysdk.pc4_centroid AS
  SELECT pc4, ST_Centroid(ST_Collect(geom)) AS geom
  FROM citysdk.postcodes
  GROUP BY pc4;
  
CREATE VIEW citysdk.pc5_centroid AS
  SELECT pc5, ST_Centroid(ST_Collect(geom)) AS geom
  FROM citysdk.postcodes
  GROUP BY pc5;
  
CREATE VIEW citysdk.pc6_centroid AS
  SELECT pc6, ST_Centroid(ST_Collect(geom)) AS geom
  FROM citysdk.postcodes
  GROUP BY pc6;
    
