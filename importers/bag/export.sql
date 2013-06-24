COPY (SELECT * FROM citysdk.standplaats) TO '/Users/bert/Documents/Waag/BAG/standplaats.csv' WITH DELIMITER ';' CSV HEADER;
COPY (SELECT * FROM citysdk.ligplaats) TO '/Users/bert/Documents/Waag/BAG/ligplaats.csv' WITH DELIMITER ';' CSV HEADER;

COPY (SELECT * FROM citysdk.pand) TO '/Users/bert/Documents/Waag/BAG/pand.csv' WITH DELIMITER ';' CSV HEADER;
COPY (SELECT * FROM citysdk.verblijfsobject) TO '/Users/bert/Documents/Waag/BAG/verblijfsobject.csv' WITH DELIMITER ';' CSV HEADER;

COPY (SELECT * FROM citysdk.pc4_centroid) TO '/Users/bert/Documents/Waag/BAG/pc4_centroid.csv' WITH DELIMITER ';' CSV HEADER;
COPY (SELECT * FROM citysdk.pc5_centroid) TO '/Users/bert/Documents/Waag/BAG/pc5_centroid.csv' WITH DELIMITER ';' CSV HEADER;
COPY (SELECT * FROM citysdk.pc6_centroid) TO '/Users/bert/Documents/Waag/BAG/pc6_centroid.csv' WITH DELIMITER ';' CSV HEADER;

 