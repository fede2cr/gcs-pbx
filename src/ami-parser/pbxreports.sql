DROP DATABASE IF EXISTS pbxreports;
CREATE DATABASE pbxreports;
USE pbxreports;
CREATE TABLE events(
	id int auto_increment,
	queue varchar(50) DEFAULT '0',
	agent int DEFAULT NULL,
	event_type varchar(32) DEFAULT 'inbound', -- transfer, abandon, pickup, login, logout, call
	uniqueid varchar(32) NOT NULL,
	event_date timestamp NOT NULL DEFAULT now(),
	PRIMARY KEY(id)
) TYPE = InnoDB;
CREATE TABLE callinfo(
	id int auto_increment,
	eventid int NOT NULL,
	src varchar(50) DEFAULT NULL,
	dst varchar(50) DEFAULT NULL,
	wait_time int,
	duration int,
	FOREIGN KEY(eventid) REFERENCES events(id) ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY(id)
) TYPE  = InnoDB;
CREATE TABLE agentinfo(
	agent int NOT NULL,
	name varchar(32)
	PRIMARY KEY(agent)
) TYPE  = InnoDB;

