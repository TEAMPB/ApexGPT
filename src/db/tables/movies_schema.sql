drop table filming_location_movie_assignment;
drop table movie;
drop table studio;
drop table location;

CREATE TABLE location (
  id NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY,
  city VARCHAR2(255),
  country VARCHAR2(255),
  CONSTRAINT location_pk PRIMARY KEY (id)
);

CREATE TABLE studio (
  id NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY,
  name VARCHAR2(255),
  headquarters_location_id NUMBER,
  CONSTRAINT studio_pk PRIMARY KEY (id),
  CONSTRAINT studio_location_fk FOREIGN KEY (headquarters_location_id) REFERENCES location(id) on delete cascade
);

CREATE TABLE movie (
  id NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY,
  title VARCHAR2(255),
  synopsis clob,
  imdb_rating NUMBER,
  pub_year DATE,
  studio_id NUMBER,
  CONSTRAINT movie_pk PRIMARY KEY (id),
  CONSTRAINT movie_studio_fk FOREIGN KEY (studio_id) REFERENCES studio(id) on delete cascade
);

CREATE TABLE filming_location_movie_assignment (
  id NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY,
  movie_id NUMBER,
  location_id NUMBER,
  CONSTRAINT filming_location_movie_assignment_pk PRIMARY KEY (id),
  CONSTRAINT filming_location_movie_assignment_movie_fk FOREIGN KEY (movie_id) REFERENCES movie(id) on delete cascade,
  CONSTRAINT filming_location_movie_assignment_location_fk FOREIGN KEY (location_id) REFERENCES location(id) on delete cascade
);
