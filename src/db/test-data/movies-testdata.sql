/*
 * GERMAN
 */ 
-- Daten in die Tabelle 'location' einfügen
INSERT INTO location (id, city, country) VALUES (1, 'Los Angeles', 'Vereinigte Staaten');
INSERT INTO location (id, city, country) VALUES (2, 'London', 'Vereinigtes Königreich');
INSERT INTO location (id, city, country) VALUES (3, 'Tokio', 'Japan');
INSERT INTO location (id, city, country) VALUES (4, 'New York City', 'Vereinigte Staaten');

-- Daten in die Tabelle 'studio' einfügen
INSERT INTO studio (id, name, headquarters_location_id) VALUES (1, 'Warner Bros.', 1);
INSERT INTO studio (id, name, headquarters_location_id) VALUES (2, 'Universal Pictures', 1);
INSERT INTO studio (id, name, headquarters_location_id) VALUES (3, 'Toho Studios', 3);
INSERT INTO studio (id, name, headquarters_location_id) VALUES (4, '20th Century Fox', 4);

-- Daten in die Tabelle 'movie' einfügen
INSERT INTO movie (id, title, synopsis, imdb_rating, pub_year, studio_id) VALUES (1, 'The Dark Knight', 'Als die Bedrohung durch den Joker Chaos und Verwüstung über die Menschen von Gotham bringt, muss Batman eine der größten psychologischen und physischen Prüfungen seines Kampfes gegen das Unrecht bestehen.', 9.0, TO_DATE('2008-07-18', 'YYYY-MM-DD'), 1);
INSERT INTO movie (id, title, synopsis, imdb_rating, pub_year, studio_id) VALUES (2, 'Jurassic Park', 'Während einer Vorschau-Tour erleidet ein Themenpark einen großen Stromausfall, der dazu führt, dass seine geklonten Dinosaurier-Exponate Amok laufen.', 8.1, TO_DATE('1993-06-11', 'YYYY-MM-DD'), 2);
INSERT INTO movie (id, title, synopsis, imdb_rating, pub_year, studio_id) VALUES (3, 'Godzilla', 'Die Welt wird von dem Auftreten monströser Kreaturen heimgesucht, aber eines von ihnen könnte die einzige Hoffnung sein, die Menschheit zu retten.', 6.4, TO_DATE('2014-05-16', 'YYYY-MM-DD'), 3);
INSERT INTO movie (id, title, synopsis, imdb_rating, pub_year, studio_id) VALUES (4, 'Der Teufel trägt Prada', 'Eine kluge, aber vernünftige Hochschulabsolventin bekommt einen Job als Assistentin von Miranda Priestly, der anspruchsvollen Chefredakteurin eines hochkarätigen Modemagazins.', 6.9, TO_DATE('2006-06-30', 'YYYY-MM-DD'), 4);

-- Daten in die Tabelle 'filming_location_movie_assignment' einfügen
INSERT INTO filming_location_movie_assignment (movie_id, location_id) VALUES (1, 1);
INSERT INTO filming_location_movie_assignment (movie_id, location_id) VALUES (2, 2);
INSERT INTO filming_location_movie_assignment (movie_id, location_id) VALUES (3, 3);
INSERT INTO filming_location_movie_assignment (movie_id, location_id) VALUES (4, 4);

/*
ENGLISH

-- Inserting data into the location table
INSERT INTO location (id, city, country) VALUES (1, 'Los Angeles', 'United States');
INSERT INTO location (id, city, country) VALUES (2, 'London', 'United Kingdom');
INSERT INTO location (id, city, country) VALUES (3, 'Tokyo', 'Japan');
INSERT INTO location (id, city, country) VALUES (4, 'New York City', 'United States');

-- Inserting data into the studio table
INSERT INTO studio (id, name, headquarters_location_id) VALUES (1, 'Warner Bros.', 1);
INSERT INTO studio (id, name, headquarters_location_id) VALUES (2, 'Universal Pictures', 1);
INSERT INTO studio (id, name, headquarters_location_id) VALUES (3, 'Toho Studios', 3);
INSERT INTO studio (id, name, headquarters_location_id) VALUES (4, '20th Century Fox', 4);

-- Inserting data into the movie table
INSERT INTO movie (id, title, synopsis, imdb_rating, pub_year, studio_id) VALUES (1, 'The Dark Knight', 'When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice.', 9.0, TO_DATE('2008-07-18', 'YYYY-MM-DD'), 1);
INSERT INTO movie (id, title, synopsis, imdb_rating, pub_year, studio_id) VALUES (2, 'Jurassic Park', 'During a preview tour, a theme park suffers a major power breakdown that allows its cloned dinosaur exhibits to run amok.', 8.1, TO_DATE('1993-06-11', 'YYYY-MM-DD'), 2);
INSERT INTO movie (id, title, synopsis, imdb_rating, pub_year, studio_id) VALUES (3, 'Godzilla', 'The world is beset by the appearance of monstrous creatures, but one of them may be the only one who can save humanity.', 6.4, TO_DATE('2014-05-16', 'YYYY-MM-DD'), 3);
INSERT INTO movie (id, title, synopsis, imdb_rating, pub_year, studio_id) VALUES (4, 'The Devil Wears Prada', 'A smart but sensible new graduate lands a job as an assistant to Miranda Priestly, the demanding editor-in-chief of a high fashion magazine.', 6.9, TO_DATE('2006-06-30', 'YYYY-MM-DD'), 4);

-- Inserting data into the filming_location_movie_assignment table
INSERT INTO filming_location_movie_assignment (id, movie_id, location_id) VALUES (1, 1, 1);
INSERT INTO filming_location_movie_assignment (id, movie_id, location_id) VALUES (2, 2, 2);
INSERT INTO filming_location_movie_assignment (id, movie_id, location_id) VALUES (3, 3, 3);
INSERT INTO filming_location_movie_assignment (id, movie_id, location_id) VALUES (4, 4, 4);
*/