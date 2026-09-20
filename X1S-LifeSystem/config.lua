Config = {}

Config.Locale = 'en' -- Supported: en (extend locales.json to add more)

Config.Notifications = {
    position = 'top-right', -- top-right, top-left, bottom-right, bottom-left
    duration = 5500,
    dispatchDuration = 10000,
    panicDuration = 12000,
    maxVisible = 5,
    sound = true,
    announceDutyChanges = true
}

Config.Departments = {
    LSPD = {
        label = 'Los Santos Police Department',
        blip = { sprite = 672, color = 38 },
        cad = true,
        logo = 'images/lspd.png'
    },
    BCSO = {
        label = 'Blaine County Sheriffs Office',
        blip = { sprite = 672, color = 47 },
        cad = true,
        logo = 'images/bcso.png'
    },
    SAST = {
        label = 'San Andreas State Troopers',
        blip = { sprite = 672, color = 26 },
        cad = true,
        logo = 'images/sast.png'
    },
    SAGW = {
        label = 'San Andreas Game Warden',
        blip = { sprite = 672, color = 25 },
        cad = true,
        logo = 'images/sagw.png'
    }
}

Config.Emergency = {
    reportMaxLength = 256,
    blipDuration = 120000,
    defaultPriority = 'medium',
    priorityKeywords = {
        high = { 'gun', 'shoot', 'shots fired', 'weapon', 'stab', 'knife', 'hostage', 'robbery' },
        medium = { 'steal', 'theft', 'stolen', 'break in', 'breakin', 'assault', 'fight' },
        low = { 'noise', 'suspicious', 'parking', 'trespass' }
    }
}

Config.Panic = {
    blipDuration = 120000
}

Config.AutoDispatch = {
    enabled = true,

    carjacking = {
        enabled = true,
        cooldown = false,
        priority = 'high'
    },

    shotsFired = {
        enabled = true,
        cooldown = 45,
        priority = 'high',
        ignoreOnDutyOfficers = false
    },

    gunPulledPublic = {
        enabled = true,
        cooldown = 60,
        priority = 'medium',
        ignoreOnDutyOfficers = true,
        excludeInteriors = true,
        requireNpcNearby = true,
        npcRadius = 15.0,
        excludeZones = {}
    },

    fightInProgress = {
        enabled = true,
        cooldown = 45,
        priority = 'medium',
        ignoreOnDutyOfficers = false
    }
}

Config.Sync = {
    coordinateUpdateInterval = 2000,
    blipBroadcastInterval = 2000
}

Config.TabletAnim = {
    enabled = true,
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
    anim = 'base',
    flag = 49,
    playOnFoot = true,
    clearWeapon = true,
    prop = {
        model = 'prop_cs_tablet',
        bone = 60309,
        boneOffset = vector3(0.03, 0.002, 0.0),
        boneRotation = vector3(10.0, 160.0, 0.0)
    }
}

Config.Character = {
    maxCharacters = 5,
    allowDelete = true,
    creatorCoords = vector4(668.5195, 1046.3909, 336.8073, 339.2921),
    creatorCam = { distance = 6.0, height = 0.55, fov = 55.0 },
    minAge = 18,
    maxAge = 90,
    minHeight = 150,
    maxHeight = 210,
    genders = {
        { key = 'male',   label = 'Male',   model = 'mp_m_freemode_01' },
        { key = 'female', label = 'Female', model = 'mp_f_freemode_01' }
    },

    Licenses = {
        { key = 'driver',     label = 'Driver License',      command = 'handdriverlicense',     cardTitle = 'DRIVER LICENSE',            class = 'A', endorsement = 'NONE', color = { a = '#dce8f7', b = '#c3d8ef' } },
        { key = 'motorcycle', label = 'Motorcycle License',  command = 'handmotorcyclelicense', cardTitle = 'MOTORCYCLE LICENSE',        class = 'M', endorsement = 'NONE', color = { a = '#dcefdc', b = '#c2e0c2' } },
        { key = 'cdl',        label = 'CDL',                 command = 'handcdl',               cardTitle = 'COMMERCIAL DRIVER LICENSE', class = 'C', endorsement = 'NONE', color = { a = '#fbe6cf', b = '#f5d3ab' } },
        { key = 'firearm',    label = 'Firearm License',     command = 'handweaponlicense',     cardTitle = 'FIREARM CARRY LICENSE',     class = false, endorsement = false, color = { a = '#f7dcdc', b = '#efc2c2' } },
        { key = 'hunting',    label = 'Hunting License',     command = 'handhuntinglicense',    cardTitle = 'HUNTING LICENSE',           class = false, endorsement = false, color = { a = '#e8ecd2', b = '#d9deb0' } },
        { key = 'boating',    label = 'Boating License',     command = 'handboatinglicense',    cardTitle = 'BOATING LICENSE',           class = false, endorsement = false, color = { a = '#d2eeee', b = '#b3dede' } },
        { key = 'pilot',      label = 'Pilot License',       command = 'handpilotlicense',      cardTitle = 'PILOT LICENSE',             class = false, endorsement = false, color = { a = '#e6dcf2', b = '#d3c2e8' } }
    }
}

Config.IDCards = {
    radius = 3.0,
    validityYears = 5,
    command = 'handid',
    cardTitle = 'IDENTIFICATION CARD',
    stateName = 'SAN ANDREAS',
    color = { a = '#f8edd2', b = '#efdcae' },
    silhouettes = {
        male = 'images/id-silhouette-male.png',
        female = 'images/id-silhouette-female.png'
    }
}

Config.Spawn = {
    command = 'spawnselector',
    loadingDuration = 20000,
    allowManualClose = true,

    defaultCam = {
        distance = 8.0,
        height = 4.0,
        fov = 55.0
    },
    locations = {
        { name = 'Legion Square',   district = 'Downtown Los Santos',  coords = vector4(223.5, -867.02, 30.49, 11.52),   image = 'images/legion.png' },
        { name = 'Vespucci Beach',  district = 'Vespucci',             coords = vector4(-1191.4, -1571.2, 4.6, 210.0),  image = 'images/vespucci.png' },
        { name = 'Sandy Shores',    district = 'Blaine County',        coords = vector4(2045.10, 3445.99, 43.77, 8.09), image = 'images/sandyspawn.png' },
        { name = 'Paleto Bay',      district = 'Blaine County',        coords = vector4(1590.65, 6450.98, 25.32, 155.38), image = 'images/paleto.png' },
        { name = 'MRPD Station',    district = 'Los Santos',           coords = vector4(411.63, -966.19, 29.47, 226.55), image = 'images/mrpd.png' },
        { name = 'Del Perro Pier',  district = 'Del Perro',            coords = vector4(-1850.9, -1232.9, 13.0, 45.0),  image = 'images/del-perro-pier.png' },
        { name = 'Sheriff Station', district = 'Blaine County',        coords = vector4(2487.83, 1612.5, 30.39, 268.74), image = 'images/sheriff.png' },
        { name = 'Mirror Park',     district = 'East Los Santos',      coords = vector4(700.39, -303.02, 59.24, 11.51), image = 'images/mirrorpark.png' }
    }
}

Config.CAD = {
    command = 'cad',
    keybind = 'F6',
    accessDepartments = { 'LSPD', 'BCSO', 'SAST', 'SAGW' },
    searchMinLength = 2,
    maxSearchResults = 25,
    citationMaxFine = 50000,
    warrantDefaultDurationDays = 30,
    arrestChargeMaxFine = 100000,
    arrestChargeMaxJailMinutes = 1440,
    citationLineMaxFine = 10000,
    warrantDurationPresets = { 7, 14, 30, 60, 90 },
    vehicleRegistrationRenewalPresets = { 30, 90, 180, 365 },
    vehicleBoloPriorities = {
        { key = 'routine',  label = 'Routine',           color = 'gray' },
        { key = 'priority', label = 'Priority',          color = 'amber' },
        { key = 'armed',    label = 'Armed & Dangerous', color = 'red-bright' }
    },
    statuses = {
        { key = 'active',       label = 'Active',          color = 'green' },
        { key = 'busy',         label = 'Busy',            color = 'amber' },
        { key = 'onscene',      label = 'On Scene',        color = 'red-bright' },
        { key = 'enroute',      label = 'En Route',        color = 'blue' },
        { key = 'outofservice', label = 'Out of Service',  color = 'gray' }
    },
    charges = {
        { code = '69.01', label = 'Speeding',                 fine = 250,  jailMinutes = 0,  citable = true },
        { code = '69.02', label = 'Reckless Driving',          fine = 750,  jailMinutes = 5,  citable = true },
        { code = '69.03', label = 'Evading Police',            fine = 2500, jailMinutes = 15, citable = false },
        { code = '14.01', label = 'Petty Theft',                fine = 500,  jailMinutes = 5,  citable = true },
        { code = '14.02', label = 'Grand Theft Auto',           fine = 3500, jailMinutes = 20, citable = false },
        { code = '14.03', label = 'Robbery',                    fine = 5000, jailMinutes = 30, citable = false },
        { code = '22.01', label = 'Assault',                    fine = 1500, jailMinutes = 10, citable = false },
        { code = '22.02', label = 'Assault on an Officer',      fine = 5000, jailMinutes = 25, citable = false },
        { code = '22.03', label = 'Murder',                     fine = 0,    jailMinutes = 60, citable = false },
        { code = '35.01', label = 'Possession of a Firearm (unlicensed)', fine = 2000, jailMinutes = 15, citable = false },
        { code = '35.02', label = 'Discharging a Firearm',      fine = 1000, jailMinutes = 10, citable = false },
        { code = '40.01', label = 'Trespassing',                fine = 250,  jailMinutes = 0,  citable = true },
        { code = '40.02', label = 'Public Intoxication',        fine = 150,  jailMinutes = 0,  citable = true },
        { code = '40.03', label = 'Resisting Arrest',           fine = 1000, jailMinutes = 10, citable = false }
    }
}

Config.CAD.tenCodes = {
    { code = "10-1", label = "Unable To Copy Re-Locate" },
    { code = "10-2", label = "Signals Good" },
    { code = "10-3", label = "Stop Transmitting" },
    { code = "10-4", label = "Acknowledgement" },
    { code = "10-5", label = "Relay" },
    { code = "10-6", label = "Busy Stand-By" },
    { code = "10-7", label = "Out of Service" },
    { code = "10-8", label = "In Service" },
    { code = "10-9", label = "Repeat" },
    { code = "10-10", label = "Fight In Progress" },
    { code = "10-11", label = "Vehicle Chase" },
    { code = "10-12", label = "Stand-By (stop)" },
    { code = "10-13", label = "Weather & Road Report" },
    { code = "10-14", label = "Report of Prowler" },
    { code = "10-15", label = "Civil Disturbance" },
    { code = "10-16", label = "Domestic Trouble" },
    { code = "10-17", label = "Meet Complainant" },
    { code = "10-18", label = "Complete Assgn. Quickly" },
    { code = "10-19", label = "Return To …" },
    { code = "10-20", label = "Location" },
    { code = "10-21", label = "Call … By Telephone" },
    { code = "10-22", label = "Disregard" },
    { code = "10-23", label = "Arrived At Scene" },
    { code = "10-24", label = "Assignment Completed" },
    { code = "10-25", label = "Report In Person To …" },
    { code = "10-26", label = "Detaining Subject Expid" },
    { code = "10-27", label = "Drivers License Information" },
    { code = "10-28", label = "Vehicle Registration" },
    { code = "10-29", label = "Check Records for Want" },
    { code = "10-30", label = "Illegal Use of Radio" },
    { code = "10-31", label = "Crime In Progress" },
    { code = "10-32", label = "Man With Gun" },
    { code = "10-33", label = "Emergency" },
    { code = "10-34", label = "Riot" },
    { code = "10-35", label = "Major Crime Alert" },
    { code = "10-36", label = "Correct Time" },
    { code = "10-37", label = "Inves. Susp. Vehicle" },
    { code = "10-38", label = "Stopping Susp. Vehicle (give complete descript)" },
    { code = "10-39", label = "Urgent (light/siren)" },
    { code = "10-40", label = "Silent Run" },
    { code = "10-41", label = "Beginning Tour of Duty" },
    { code = "10-42", label = "Ending Tour of Duty" },
    { code = "10-43", label = "Information" },
    { code = "10-44", label = "Request Permission To Leave Patrol … for …" },
    { code = "10-45", label = "Animal Carcass in Road" },
    { code = "10-46", label = "Assist Motorist" },
    { code = "10-47", label = "Emerg. Road Repairs Needed" },
    { code = "10-48", label = "Traffic Standard Repair" },
    { code = "10-49", label = "Traffic Light Out" },
    { code = "10-50", label = "Traffic Accident-F" },
    { code = "10-51", label = "Wrecker Needed" },
    { code = "10-52", label = "Ambulance Needed" },
    { code = "10-53", label = "Road Blocked" },
    { code = "10-54", label = "Livestock On Highway" },
    { code = "10-55", label = "Intoxicated Driver" },
    { code = "10-56", label = "Intoxicated Person" },
    { code = "10-57", label = "Hit & Run … F" },
    { code = "10-58", label = "Direct Traffic" },
    { code = "10-59", label = "Convoy or Escort" },
    { code = "10-60", label = "Squad In Vicinity" },
    { code = "10-61", label = "Personnel In Area" },
    { code = "10-62", label = "Reply To Message" },
    { code = "10-63", label = "Prepare To Make Written Cpy" },
    { code = "10-64", label = "Message for Local Del" },
    { code = "10-65", label = "Net Message Assgn" },
    { code = "10-66", label = "Message Cancellation" },
    { code = "10-67", label = "Clear To Read Net Msg" },
    { code = "10-68", label = "Dispatch Information" },
    { code = "10-69", label = "Message Received" },
    { code = "10-70", label = "Fire Alarm" },
    { code = "10-71", label = "Advise Nature of Fire (size" },
    { code = "10-72", label = "Report Progress On Fire" },
    { code = "10-73", label = "Smoke Report" },
    { code = "10-74", label = "Negative" },
    { code = "10-75", label = "In Contact With" },
    { code = "10-76", label = "En Route" },
    { code = "10-77", label = "ETA" },
    { code = "10-78", label = "Need Assistance" },
    { code = "10-79", label = "Notify Coroner" },
    { code = "10-82", label = "Reserve Lodging" },
    { code = "10-84", label = "If Meeting … Advise ETA" },
    { code = "10-85", label = "Will Be Late" },
    { code = "10-87", label = "Pick Up Checks for District" },
    { code = "10-88", label = "Advise Telephone # of …" },
    { code = "10-90", label = "Bank Alarm" },
    { code = "10-91", label = "Unnecessary Use of Radio" },
    { code = "10-93", label = "Blockade" },
    { code = "10-94", label = "Drag Racing" },
    { code = "10-96", label = "Mental Subject" },
    { code = "10-98", label = "Prison/Jail Break" },
    { code = "10-99", label = "Records Indicate Want/Stolen" }
}

Config.CAD.penalCodes = {
    { title = "Murder", code = "(CA)187", type = "Felony", bondType = "Federal Bail Bond", bondAmount = 500000, jailTime = "25 Years to Life" },
    { title = "Manslaughter", code = "(CA)192", type = "Felony", bondType = "State Bail Bond", bondAmount = 250000, jailTime = "3-11 Years" },
    { title = "Mayhem", code = "(CA)203", type = "Felony", bondType = "State Bail Bond", bondAmount = 150000, jailTime = "2-8 Years" },
    { title = "Kidnapping", code = "(CA)207", type = "Felony", bondType = "Federal Bail Bond", bondAmount = 200000, jailTime = "3-8 Years" },
    { title = "Robbery", code = "(CA)211", type = "Felony", bondType = "Federal Bail Bond", bondAmount = 200000, jailTime = "3-9 Years" },
    { title = "Carjacking", code = "(CA)215", type = "Felony", bondType = "Federal Bail Bond", bondAmount = 200000, jailTime = "3-9 Years" },
    { title = "Assault", code = "(CA)240", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 5000, jailTime = "Up to 6 Months" },
    { title = "Battery", code = "(CA)242", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 5000, jailTime = "Up to 6 Months" },
    { title = "Assault with a Deadly Weapon", code = "(CA)245", type = "Felony", bondType = "State Bail Bond", bondAmount = 100000, jailTime = "2-4 Years" },
    { title = "Rape", code = "(CA)261", type = "Felony", bondType = "Federal Bail Bond", bondAmount = 250000, jailTime = "3-8 Years" },
    { title = "Domestic Violence", code = "(CA)273.5", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "2-4 Years" },
    { title = "Child Molestation", code = "(CA)288", type = "Felony", bondType = "Federal Bail Bond", bondAmount = 250000, jailTime = "3-8 Years" },
    { title = "Indecent Exposure", code = "(CA)314", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 5000, jailTime = "Up to 6 Months" },
    { title = "Elder Abuse", code = "(CA)368", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "2-4 Years" },
    { title = "Disturbing the Peace", code = "(CA)415", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 2500, jailTime = "Up to 90 Days" },
    { title = "Brandishing a Weapon", code = "(CA)417", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 5000, jailTime = "Up to 1 Year" },
    { title = "Criminal Threats", code = "(CA)422", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "2-4 Years" },
    { title = "Arson", code = "(CA)451", type = "Felony", bondType = "Federal Bail Bond", bondAmount = 200000, jailTime = "2-9 Years" },
    { title = "Burglary", code = "(CA)459", type = "Felony", bondType = "State Bail Bond", bondAmount = 100000, jailTime = "2-6 Years" },
    { title = "Forgery", code = "(CA)470", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Petty Theft", code = "(CA)484", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 2500, jailTime = "Up to 6 Months" },
    { title = "Grand Theft", code = "(CA)487", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Receiving Stolen Property", code = "(CA)496", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Embezzlement", code = "(CA)503", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Extortion", code = "(CA)518", type = "Felony", bondType = "State Bail Bond", bondAmount = 100000, jailTime = "2-4 Years" },
    { title = "False Personation", code = "(CA)528", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 5000, jailTime = "Up to 1 Year" },
    { title = "Vandalism", code = "(CA)594", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 5000, jailTime = "Up to 1 Year" },
    { title = "Animal Cruelty", code = "(CA)597", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Trespassing", code = "(CA)602", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 2500, jailTime = "Up to 6 Months" },
    { title = "Stalking", code = "(CA)646.9", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "2-5 Years" },
    { title = "Prostitution", code = "(CA)647(b)", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 2500, jailTime = "Up to 6 Months" },
    { title = "Public Intoxication", code = "(CA)647(f)", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 2500, jailTime = "Up to 6 Months" },
    { title = "Attempted Crime", code = "(CA)664", type = "Felony", bondType = "Varies", bondAmount = 0, jailTime = "Varies" },
    { title = "Felon in Possession of a Firearm", code = "(CA)29800", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Possession of Short-Barreled Rifle or Shotgun", code = "(CA)33215", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Prohibited Person in Possession of Ammunition", code = "(CA)30305", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Carrying a Concealed Firearm", code = "(CA)25400", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Carrying a Loaded Firearm in Public", code = "(CA)25850", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Unlawful Transfer of Firearm", code = "(CA)27545", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 2500, jailTime = "Up to 6 Months" },
    { title = "Possession of Assault Weapon", code = "(CA)30605", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Possession of a Machine Gun", code = "(CA)33210", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Possession of a Silencer", code = "(CA)33410", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Participation in a Criminal Street Gang", code = "(CA)186.22", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Infliction of Great Bodily Injury", code = "(CA)12022.7", type = "Felony", bondType = "State Bail Bond", bondAmount = 100000, jailTime = "3-6 Years" },
    { title = "Use of Firearm in Commission of Felony", code = "(CA)12022.5", type = "Felony", bondType = "State Bail Bond", bondAmount = 150000, jailTime = "3-10 Years" },
    { title = "Discharge of Firearm from Vehicle", code = "(CA)12034", type = "Felony", bondType = "State Bail Bond", bondAmount = 100000, jailTime = "3-7 Years" },
    { title = "Drive-By Shooting", code = "(CA)26100", type = "Felony", bondType = "State Bail Bond", bondAmount = 100000, jailTime = "3-7 Years" },
    { title = "Child Endangerment", code = "(CA)273a", type = "Felony", bondType = "State Bail Bond", bondAmount = 100000, jailTime = "2-6 Years" },
    { title = "Child Abuse", code = "(CA)273d", type = "Felony", bondType = "State Bail Bond", bondAmount = 100000, jailTime = "2-6 Years" },
    { title = "Hate Crime", code = "(CA)422.6", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 5000, jailTime = "Up to 1 Year" },
    { title = "False Impersonation", code = "(CA)529", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Identity Theft", code = "(CA)530.5", type = "Felony", bondType = "State Bail Bond", bondAmount = 75000, jailTime = "16 Months to 3 Years" },
    { title = "Cyber Harassment", code = "(CA)653.2", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 5000, jailTime = "Up to 1 Year" },
    { title = "Annoying Phone Calls", code = "(CA)653m", type = "Misdemeanor", bondType = "Personal Recognizance", bondAmount = 2500, jailTime = "Up to 6 Months" },
    { title = "Evading a Police Officer in a Vehicle", code = "2800.1 VC", type = "Misdemeanor", bondType = "Federal Bail Bond", bondAmount = 1000, jailTime = "1-5 Years" },
    { title = "Possession of a Controlled Substance", code = "11350(a)", type = "Misdemeanor", bondType = "Federal Bail Bond", bondAmount = 10000, jailTime = "5-10 Years" },
    { title = "Attempted Murder", code = "PC 664/187(a)", type = "Felony", bondType = "Federal Bail Bond", bondAmount = 250000, jailTime = "5-Years - Life" },
    { title = "Driving Without A License", code = "12500(a) VC", type = "Misdemeanor", bondType = "Federal Bail Bond", bondAmount = 1000, jailTime = "Six Months" }
}

Config.CAD.PenalChargeIntegration = {
    fineMultiplier = 1.0,
    jailMinutesDivisor = 6000,
    jailMinutesCap = 90
}

do
    local integ = Config.CAD.PenalChargeIntegration
    local existingCodes = {}
    for _, c in ipairs(Config.CAD.charges) do existingCodes[c.code] = true end

    for _, pc in ipairs(Config.CAD.penalCodes) do
        if not existingCodes[pc.code] then
            existingCodes[pc.code] = true
            local jailMinutes = math.min(integ.jailMinutesCap, math.floor(pc.bondAmount / integ.jailMinutesDivisor))
            Config.CAD.charges[#Config.CAD.charges + 1] = {
                code = pc.code,
                label = pc.title,
                fine = math.floor(pc.bondAmount * integ.fineMultiplier),
                jailMinutes = jailMinutes,
                citable = (pc.type == 'Misdemeanor')
            }
        end
    end
end

Config.VehicleRegistration = {
    command = 'registervehicle',
    maxOwnedVehicles = 100,
    brandMaxLength = 32,
    typeMaxLength = 64,
    modelMaxLength = 64,
    colorMaxLength = 32,
    plateMinLength = 2,
    plateMaxLength = 16,
    plateStateMaxLength = 20,
    yearMin = 1900,
    yearMax = 2100,
    registrationValidDays = 365
}

Config.Robbery = {
    enabled = true,

    interactControl = 51,
    hackControl = 22,
    cancelControl = 200,

    interactDistance = 1.6,
    markerDistance = 18.0,
    createBlips = true,

    blockOnDuty = true,

    maxStartDistance = 4.0,

    locationCooldown = {
        bank = 1800,
        atm = 600,
        store = 900
    },

    playerCooldown = {
        bank = 900,
        atm = 420,
        store = 420
    },

    cancelLocationCooldown = 120,

    fingerprint = {
        bank = {
            rings = 5,
            baseSpeedDegPerSec = 110,
            speedStepDegPerSec = 28,
            zoneDegrees = 46,
            zoneShrinkDegrees = 5,
            minZoneDegrees = 18,
            maxMistakes = 3,
            timeoutSeconds = 55
        },
        atm = {
            rings = 3,
            baseSpeedDegPerSec = 130,
            speedStepDegPerSec = 30,
            zoneDegrees = 48,
            zoneShrinkDegrees = 5,
            minZoneDegrees = 22,
            maxMistakes = 3,
            timeoutSeconds = 35
        }
    },

    progressBar = {
        durationMs = 22000
    },

    locations = {
        -- Banks
        { id = 'bank_legion',      type = 'bank',  label = 'Fleeca Bank - Postal 206',           coords = vector3(147.08, -1044.79, 29.36) },
        { id = 'bank_pacific',     type = 'bank',  label = 'Pacific Standard - Postal 575',      coords = vector3(254.14, 225.30, 101.87) },
        { id = 'bank_68',          type = 'bank',  label = 'Fleeca Bank - Postal 940',           coords = vector3(1176.29, 2711.65, 38.08) },
        { id = 'bank_paleto',      type = 'bank',  label = 'Paleto Bank - Postal 3019',          coords = vector3(-103.56, 6477.63, 31.62) },

        -- ATMs
        { id = 'atm_legion_1',     type = 'atm',   label = 'Postal 206',                         coords = vector3(147.77, -1035.41, 29.34) },
        { id = 'atm_vespucci',     type = 'atm',   label = 'Postal 575',                         coords = vector3(264.83, 212.04, 106.28) },
        { id = 'atm_sandy',        type = 'atm',   label = 'Postal 1036',                        coords = vector3(2004.85, 3785.20, 32.18) },
        { id = 'atm_68',           type = 'atm',   label = 'Postal 940',                         coords = vector3(1171.89, 2702.53, 38.17) },
        { id = 'atm_paletogas',    type = 'atm',   label = 'Postal 3025',                        coords = vector3(155.43, 6642.45, 31.61) },

        -- 24/7s and gas stations
        { id = 'store_strawberry', type = 'store', label = '24/7 - Postal 125',                  coords = vector3(28.03, -1339.22, 29.49) },
        { id = 'store_grove',      type = 'store', label = 'LTD - Postal 120',                   coords = vector3(-43.37, -1748.67, 29.42) },
        { id = 'store_mirrorpark', type = 'store', label = 'LTD - Postal 411',                   coords = vector3(1159.85, -314.09, 69.20) },
        { id = 'store_sandy',      type = 'store', label = '24/7 - Postal 1036',                 coords = vector3(1959.22, 3748.77, 32.34) },
        { id = 'store_paleto',     type = 'store', label = '24/7 - Postal 3030',                 coords = vector3(1734.67, 6420.66, 35.03) }
    }
}

local localePath = 'locales.json'
local rawLocales = LoadResourceFile(GetCurrentResourceName(), localePath)
assert(rawLocales, ('[X1S] Unable to read %s. Ensure it is included in fxmanifest.lua.'):format(localePath))

local decodeSucceeded, decodedLocales = pcall(json.decode, rawLocales)
assert(
    decodeSucceeded and type(decodedLocales) == 'table',
    ('[X1S] %s contains invalid JSON.'):format(localePath)
)
assert(type(decodedLocales.en) == 'table', '[X1S] locales.json must contain an English fallback.')
assert(
    type(decodedLocales[Config.Locale]) == 'table',
    ('[X1S] Unsupported locale: %s'):format(tostring(Config.Locale))
)

Locales = decodedLocales
X1S = X1S or {}

function X1S.Translate(key, ...)
    local selectedLocale = Locales[Config.Locale]
    local value = selectedLocale[key] or Locales.en[key] or key
    if select('#', ...) == 0 then return value end

    local formatSucceeded, translated = pcall(string.format, value, ...)
    if not formatSucceeded then
        print(('^3[X1S] Translation format failed for key %s in locale %s.^0'):format(key, Config.Locale))
        return value
    end

    return translated
end

X1S.Server = X1S.Server or {
    DutyPlayers = {},
    PendingDuty = {},
    Cooldowns = {},
    Active911Calls = {},
    ActivePanicAlerts = {},
    ActiveCharacter = {},
    Sessions = {},

    RobberyLocations = {},
    RobberyActive = {}
}

X1S.Client = X1S.Client or {
    OnDuty = false,
    Department = nil,
    Character = nil,
    CadOpen = false
}
