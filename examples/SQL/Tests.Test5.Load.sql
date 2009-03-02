CREATE TABLE Party (
	-- Party has PartyId,
	PartyId                                 int IDENTITY NOT NULL,
	-- maybe PartyMoniker is where Party is called PartyName and PartyMoniker has Accuracy and Accuracy has AccuracyLevel,
	PartyMonikerAccuracyLevel               int NULL CHECK((PartyMonikerAccuracyLevel >= 1 AND PartyMonikerAccuracyLevel <= 5)),
	-- maybe PartyMoniker is where Party is called PartyName and PartyMoniker is where Party is called PartyName,
	PartyMonikerPartyName                   varchar NULL,
	-- maybe Person is a subtype of Party and Birth is where Person was born on EventDate and maybe Birth was assisted by attending-Doctor and Party has PartyId,
	PersonAttendingDoctorId                 int NULL,
	-- maybe Person is a subtype of Party and Death is where Person died and maybe Death occurred on death-EventDate and EventDate has ymd,
	PersonDeathDeathEventDateYmd            datetime NULL,
	-- maybe Person is a subtype of Party and Birth is where Person was born on EventDate and Birth is where Person was born on EventDate and EventDate has ymd,
	PersonEventDateYmd                      datetime NULL,
	PRIMARY KEY(PartyId),
	FOREIGN KEY (PersonAttendingDoctorId) REFERENCES Party (PartyId)
)
GO

CREATE VIEW dbo.BirthInParty_PersonAttendingDoctorIdPersonEventDateYmd (PersonAttendingDoctorId, PersonEventDateYmd) WITH SCHEMABINDING AS
	SELECT PersonAttendingDoctorId, PersonEventDateYmd FROM dbo.Party
	WHERE	PersonAttendingDoctorId IS NOT NULL
	  AND	PersonEventDateYmd IS NOT NULL
GO

CREATE UNIQUE CLUSTERED INDEX IX_BirthInPartyByPersonAttendingDoctorIdPersonEventDateYmd ON dbo.BirthInParty_PersonAttendingDoctorIdPersonEventDateYmd(PersonAttendingDoctorId, PersonEventDateYmd)
GO

