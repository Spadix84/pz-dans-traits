-- Project Zomboid Vitality Project: the hand-edited side of the reading table. Loaded after
-- the generated DanTraits_ReadingData.lua and read by
-- DanTraits_Reading.lua.
--
--   D.real       real books from before July 1993, mixed in alongside the
--                game's fictional titles (an OnFillContainer swap of a vanilla
--                subject book at the sandbox chance, DanTraits_Reading.lua).
--                Only the title and the author's name are used. Each row:
--                key, { title, author, pages, family, quality 1-5, cover S/H/B }.
--                Page counts are the common first editions, give or take.
--   D.overrides  fixes on top of the generated rows, by vanilla title key:
--                { family = , pages = , quality = }, any field.
--
-- The item's name is "Book: "Title", by Author" like a vanilla one, and its
-- literatureTitle is IGUI_DVF_BookTitle_<key> (the prefix from when reading
-- lived in Dan's Vanilla Fixes, kept so saves carry on), so the game's own
-- read-tracking and tooltip work on it unchanged.
DanTraits_ReadingData = DanTraits_ReadingData or {}
local D = DanTraits_ReadingData

D.real = {}
local function R(key, title, author, pages, family, quality, cover)
    D.real[key] = { title = title, author = author, pages = pages, family = family, quality = quality, cover = cover or "B" }
end

-- Thrillers & Crime
R("JurassicPark", "Jurassic Park", "Michael Crichton", 399, "thrillers", 4, "B")
R("TheFirm", "The Firm", "John Grisham", 421, "thrillers", 4, "B")
R("ThePelicanBrief", "The Pelican Brief", "John Grisham", 436, "thrillers", 3, "B")
R("ATimeToKill", "A Time to Kill", "John Grisham", 515, "thrillers", 4, "B")
R("TheSilenceOfTheLambs", "The Silence of the Lambs", "Thomas Harris", 338, "thrillers", 5, "B")
R("RedDragon", "Red Dragon", "Thomas Harris", 348, "thrillers", 4, "S")
R("TheHuntForRedOctober", "The Hunt for Red October", "Tom Clancy", 387, "thrillers", 4, "B")
R("RedStormRising", "Red Storm Rising", "Tom Clancy", 652, "thrillers", 3, "B")
R("PatriotGames", "Patriot Games", "Tom Clancy", 540, "thrillers", 3, "B")
R("ClearAndPresentDanger", "Clear and Present Danger", "Tom Clancy", 656, "thrillers", 3, "H")
R("PresumedInnocent", "Presumed Innocent", "Scott Turow", 421, "thrillers", 4, "B")
R("TheBourneIdentity", "The Bourne Identity", "Robert Ludlum", 535, "thrillers", 3, "S")
R("TheDayOfTheJackal", "The Day of the Jackal", "Frederick Forsyth", 358, "thrillers", 4, "S")
R("TheSpyWhoCameInFromTheCold", "The Spy Who Came in from the Cold", "John le Carre", 256, "thrillers", 5, "S")
R("TheMalteseFalcon", "The Maltese Falcon", "Dashiell Hammett", 217, "thrillers", 4, "S")
R("TheBigSleep", "The Big Sleep", "Raymond Chandler", 231, "thrillers", 4, "S")
R("MurderOnTheOrientExpress", "Murder on the Orient Express", "Agatha Christie", 256, "thrillers", 4, "S")
R("AndThenThereWereNone", "And Then There Were None", "Agatha Christie", 272, "thrillers", 5, "S")
R("InColdBlood", "In Cold Blood", "Truman Capote", 343, "thrillers", 5, "B")
R("HelterSkelter", "Helter Skelter", "Vincent Bugliosi", 502, "thrillers", 3, "S")
R("RisingSun", "Rising Sun", "Michael Crichton", 385, "thrillers", 3, "H")
R("TheClientLikeThis", "The Client", "John Grisham", 422, "thrillers", 3, "H")

-- Horror
R("It", "It", "Stephen King", 1138, "horror", 5, "B")
R("Misery", "Misery", "Stephen King", 338, "horror", 4, "B")
R("TheStand", "The Stand", "Stephen King", 823, "horror", 5, "B")
R("TheShining", "The Shining", "Stephen King", 447, "horror", 5, "B")
R("Carrie", "Carrie", "Stephen King", 199, "horror", 3, "S")
R("PetSematary", "Pet Sematary", "Stephen King", 374, "horror", 4, "B")
R("SalemsLot", "'Salem's Lot", "Stephen King", 439, "horror", 4, "B")
R("Cujo", "Cujo", "Stephen King", 319, "horror", 3, "S")
R("GeraldsGame", "Gerald's Game", "Stephen King", 332, "horror", 2, "H")
R("TheExorcist", "The Exorcist", "William Peter Blatty", 340, "horror", 4, "S")
R("InterviewWithTheVampire", "Interview with the Vampire", "Anne Rice", 371, "horror", 4, "B")
R("TheVampireLestat", "The Vampire Lestat", "Anne Rice", 550, "horror", 3, "S")
R("RosemarysBaby", "Rosemary's Baby", "Ira Levin", 245, "horror", 4, "S")
R("TheHauntingOfHillHouse", "The Haunting of Hill House", "Shirley Jackson", 246, "horror", 5, "S")
R("Dracula", "Dracula", "Bram Stoker", 418, "horror", 4, "B")
R("Frankenstein", "Frankenstein", "Mary Shelley", 280, "horror", 4, "S")
R("Ghost_Story", "Ghost Story", "Peter Straub", 483, "horror", 4, "S")
R("Swan_Song", "Swan Song", "Robert McCammon", 956, "horror", 4, "S")

-- Westerns
R("LonesomeDove", "Lonesome Dove", "Larry McMurtry", 843, "westerns", 5, "B")
R("TrueGrit", "True Grit", "Charles Portis", 215, "westerns", 5, "S")
R("Shane", "Shane", "Jack Schaefer", 214, "westerns", 4, "S")
R("Hondo", "Hondo", "Louis L'Amour", 192, "westerns", 3, "S")
R("TheSackettBrand", "The Sackett Brand", "Louis L'Amour", 176, "westerns", 2, "S")
R("RidersOfThePurpleSage", "Riders of the Purple Sage", "Zane Grey", 352, "westerns", 3, "S")
R("TheOxBowIncident", "The Ox-Bow Incident", "Walter Van Tilburg Clark", 309, "westerns", 4, "S")
R("BloodMeridian", "Blood Meridian", "Cormac McCarthy", 337, "westerns", 5, "S")
R("AllThePrettyHorses", "All the Pretty Horses", "Cormac McCarthy", 302, "westerns", 5, "H")
R("TheVirginian", "The Virginian", "Owen Wister", 504, "westerns", 3, "S")

-- Romance
R("TheBridgesOfMadisonCounty", "The Bridges of Madison County", "Robert James Waller", 171, "romance", 2, "H")
R("Outlander", "Outlander", "Diana Gabaldon", 627, "romance", 4, "B")
R("TheThornBirds", "The Thorn Birds", "Colleen McCullough", 533, "romance", 4, "S")
R("Rebecca", "Rebecca", "Daphne du Maurier", 380, "romance", 5, "S")
R("GoneWithTheWind", "Gone with the Wind", "Margaret Mitchell", 1037, "romance", 4, "B")
R("PrideAndPrejudice", "Pride and Prejudice", "Jane Austen", 432, "romance", 5, "S")
R("JaneEyre", "Jane Eyre", "Charlotte Bronte", 532, "romance", 4, "S")
R("WutheringHeights", "Wuthering Heights", "Emily Bronte", 416, "romance", 4, "S")
R("TheFlameAndTheFlower", "The Flame and the Flower", "Kathleen E. Woodiwiss", 512, "romance", 3, "S")
R("Scruples", "Scruples", "Judith Krantz", 475, "romance", 2, "S")
R("DoctorZhivago", "Doctor Zhivago", "Boris Pasternak", 592, "romance", 4, "S")

-- Sci-Fi & Fantasy
R("TheHobbit", "The Hobbit", "J. R. R. Tolkien", 310, "scifi", 5, "B")
R("TheFellowshipOfTheRing", "The Fellowship of the Ring", "J. R. R. Tolkien", 423, "scifi", 5, "B")
R("TheTwoTowers", "The Two Towers", "J. R. R. Tolkien", 352, "scifi", 5, "B")
R("TheReturnOfTheKing", "The Return of the King", "J. R. R. Tolkien", 416, "scifi", 5, "B")
R("Dune", "Dune", "Frank Herbert", 412, "scifi", 5, "B")
R("Foundation", "Foundation", "Isaac Asimov", 255, "scifi", 4, "S")
R("Neuromancer", "Neuromancer", "William Gibson", 271, "scifi", 4, "S")
R("EndersGame", "Ender's Game", "Orson Scott Card", 357, "scifi", 4, "S")
R("TheHitchhikersGuideToTheGalaxy", "The Hitchhiker's Guide to the Galaxy", "Douglas Adams", 224, "scifi", 5, "S")
R("StrangerInAStrangeLand", "Stranger in a Strange Land", "Robert A. Heinlein", 408, "scifi", 3, "S")
R("StarshipTroopers", "Starship Troopers", "Robert A. Heinlein", 263, "scifi", 3, "S")
R("Fahrenheit451", "Fahrenheit 451", "Ray Bradbury", 158, "scifi", 5, "S")
R("TheMartianChronicles", "The Martian Chronicles", "Ray Bradbury", 222, "scifi", 4, "S")
R("DoAndroidsDreamOfElectricSheep", "Do Androids Dream of Electric Sheep?", "Philip K. Dick", 210, "scifi", 4, "S")
R("TheLeftHandOfDarkness", "The Left Hand of Darkness", "Ursula K. Le Guin", 286, "scifi", 5, "S")
R("AWizardOfEarthsea", "A Wizard of Earthsea", "Ursula K. Le Guin", 183, "scifi", 4, "S")
R("TheColorOfMagic", "The Colour of Magic", "Terry Pratchett", 206, "scifi", 3, "S")
R("GoodOmens", "Good Omens", "Terry Pratchett and Neil Gaiman", 288, "scifi", 4, "S")
R("TheEyeOfTheWorld", "The Eye of the World", "Robert Jordan", 782, "scifi", 3, "B")
R("DragonsOfAutumnTwilight", "Dragons of Autumn Twilight", "Margaret Weis and Tracy Hickman", 448, "scifi", 3, "S")
R("Hyperion", "Hyperion", "Dan Simmons", 482, "scifi", 4, "S")
R("SnowCrash", "Snow Crash", "Neal Stephenson", 440, "scifi", 4, "H")
R("TheLionTheWitchAndTheWardrobe", "The Lion, the Witch and the Wardrobe", "C. S. Lewis", 208, "scifi", 4, "S")
R("WatershipDown", "Watership Down", "Richard Adams", 413, "scifi", 5, "S")
R("TheAndromedaStrain", "The Andromeda Strain", "Michael Crichton", 295, "scifi", 3, "S")

-- Popular Fiction
R("TheJoyLuckClub", "The Joy Luck Club", "Amy Tan", 288, "popular", 4, "B")
R("TheColorPurple", "The Color Purple", "Alice Walker", 295, "popular", 5, "S")
R("Beloved", "Beloved", "Toni Morrison", 275, "popular", 5, "B")
R("ThePrinceOfTides", "The Prince of Tides", "Pat Conroy", 567, "popular", 4, "S")
R("TheWorldAccordingToGarp", "The World According to Garp", "John Irving", 437, "popular", 4, "S")
R("APrayerForOwenMeany", "A Prayer for Owen Meany", "John Irving", 543, "popular", 5, "S")
R("TheBonfireOfTheVanities", "The Bonfire of the Vanities", "Tom Wolfe", 659, "popular", 4, "S")
R("Jaws", "Jaws", "Peter Benchley", 311, "popular", 3, "S")
R("TheGodfather", "The Godfather", "Mario Puzo", 448, "popular", 4, "S")
R("LoveStory", "Love Story", "Erich Segal", 131, "popular", 2, "S")
R("FriedGreenTomatoes", "Fried Green Tomatoes at the Whistle Stop Cafe", "Fannie Flagg", 403, "popular", 4, "S")
R("TheOutsiders", "The Outsiders", "S. E. Hinton", 192, "popular", 4, "S")
R("ARiverRunsThroughIt", "A River Runs Through It", "Norman Maclean", 217, "popular", 5, "S")
R("TheSecretHistory", "The Secret History", "Donna Tartt", 524, "popular", 4, "H")
R("Possession", "Possession", "A. S. Byatt", 511, "popular", 3, "S")

-- Classics
R("ToKillAMockingbird", "To Kill a Mockingbird", "Harper Lee", 296, "classics", 5, "B")
R("Catch22", "Catch-22", "Joseph Heller", 453, "classics", 5, "B")
R("TheGreatGatsby", "The Great Gatsby", "F. Scott Fitzgerald", 218, "classics", 5, "S")
R("TheCatcherInTheRye", "The Catcher in the Rye", "J. D. Salinger", 277, "classics", 4, "S")
R("OfMiceAndMen", "Of Mice and Men", "John Steinbeck", 107, "classics", 5, "S")
R("TheGrapesOfWrath", "The Grapes of Wrath", "John Steinbeck", 464, "classics", 5, "B")
R("EastOfEden", "East of Eden", "John Steinbeck", 601, "classics", 5, "B")
R("TheOldManAndTheSea", "The Old Man and the Sea", "Ernest Hemingway", 127, "classics", 4, "S")
R("TheSunAlsoRises", "The Sun Also Rises", "Ernest Hemingway", 251, "classics", 4, "S")
R("NineteenEightyFour", "Nineteen Eighty-Four", "George Orwell", 328, "classics", 5, "S")
R("AnimalFarm", "Animal Farm", "George Orwell", 112, "classics", 5, "S")
R("BraveNewWorld", "Brave New World", "Aldous Huxley", 311, "classics", 4, "S")
R("LordOfTheFlies", "Lord of the Flies", "William Golding", 224, "classics", 4, "S")
R("SlaughterhouseFive", "Slaughterhouse-Five", "Kurt Vonnegut", 215, "classics", 5, "S")
R("OnTheRoad", "On the Road", "Jack Kerouac", 320, "classics", 3, "S")
R("MobyDick", "Moby-Dick", "Herman Melville", 635, "classics", 4, "B")
R("HuckleberryFinn", "Adventures of Huckleberry Finn", "Mark Twain", 366, "classics", 5, "S")
R("TheAdventuresOfTomSawyer", "The Adventures of Tom Sawyer", "Mark Twain", 274, "classics", 4, "S")
R("ATaleOfTwoCities", "A Tale of Two Cities", "Charles Dickens", 489, "classics", 4, "S")
R("GreatExpectations", "Great Expectations", "Charles Dickens", 544, "classics", 4, "S")
R("CrimeAndPunishment", "Crime and Punishment", "Fyodor Dostoevsky", 551, "classics", 5, "S")
R("WarAndPeace", "War and Peace", "Leo Tolstoy", 1225, "classics", 5, "H")
R("TheCountOfMonteCristo", "The Count of Monte Cristo", "Alexandre Dumas", 1276, "classics", 5, "H")
R("TheScarletLetter", "The Scarlet Letter", "Nathaniel Hawthorne", 272, "classics", 3, "S")
R("Walden", "Walden", "Henry David Thoreau", 352, "classics", 3, "S")
R("InvisibleMan", "Invisible Man", "Ralph Ellison", 581, "classics", 5, "S")
R("TheirEyesWereWatchingGod", "Their Eyes Were Watching God", "Zora Neale Hurston", 219, "classics", 5, "S")

-- History & War
R("TheGunsOfAugust", "The Guns of August", "Barbara W. Tuchman", 511, "history", 5, "S")
R("BandOfBrothers", "Band of Brothers", "Stephen E. Ambrose", 336, "history", 4, "H")
R("TheRiseAndFallOfTheThirdReich", "The Rise and Fall of the Third Reich", "William L. Shirer", 1245, "history", 4, "H")
R("TheKillerAngels", "The Killer Angels", "Michael Shaara", 374, "history", 5, "S")
R("AllQuietOnTheWesternFront", "All Quiet on the Western Front", "Erich Maria Remarque", 296, "history", 5, "S")
R("Dispatches", "Dispatches", "Michael Herr", 260, "history", 4, "S")
R("TheThingsTheyCarried", "The Things They Carried", "Tim O'Brien", 273, "history", 5, "S")
R("APeoplesHistoryOfTheUnitedStates", "A People's History of the United States", "Howard Zinn", 614, "history", 4, "S")
R("BattleCryOfFreedom", "Battle Cry of Freedom", "James M. McPherson", 904, "history", 5, "H")
R("TheMakingOfTheAtomicBomb", "The Making of the Atomic Bomb", "Richard Rhodes", 886, "history", 5, "S")

-- True Stories
R("IntoThinAir_NotYet", "Alive", "Piers Paul Read", 352, "truestories", 4, "S")
R("TheRightStuff", "The Right Stuff", "Tom Wolfe", 436, "truestories", 5, "S")
R("AngelasAshesNo_Helter", "Kon-Tiki", "Thor Heyerdahl", 240, "truestories", 4, "S")
R("TheDiaryOfAYoungGirl", "The Diary of a Young Girl", "Anne Frank", 283, "truestories", 5, "S")
R("IKnowWhyTheCagedBirdSings", "I Know Why the Caged Bird Sings", "Maya Angelou", 281, "truestories", 5, "S")
R("TheAutobiographyOfMalcolmX", "The Autobiography of Malcolm X", "Malcolm X with Alex Haley", 460, "truestories", 5, "S")
R("Roots", "Roots", "Alex Haley", 688, "truestories", 4, "B")
R("PapillonBook", "Papillon", "Henri Charriere", 560, "truestories", 4, "S")
R("AllCreaturesGreatAndSmall", "All Creatures Great and Small", "James Herriot", 437, "truestories", 4, "S")
R("Iacocca", "Iacocca: An Autobiography", "Lee Iacocca", 352, "truestories", 2, "S")
R("DarknessVisible", "Darkness Visible", "William Styron", 84, "truestories", 4, "S")

-- Sports
R("BallFour", "Ball Four", "Jim Bouton", 400, "sports", 4, "S")
R("TheBoysOfSummer", "The Boys of Summer", "Roger Kahn", 442, "sports", 5, "S")
R("FridayNightLights", "Friday Night Lights", "H. G. Bissinger", 357, "sports", 4, "S")
R("SeabiscuitNo_Paper", "Paper Lion", "George Plimpton", 362, "sports", 4, "S")
R("TheNaturalBook", "The Natural", "Bernard Malamud", 231, "sports", 4, "S")
R("ShoelessJoe", "Shoeless Joe", "W. P. Kinsella", 265, "sports", 4, "S")
R("ASeasonOnTheBrink", "A Season on the Brink", "John Feinstein", 311, "sports", 3, "S")
R("GolfMyWay", "Golf My Way", "Jack Nicklaus", 264, "sports", 3, "S")

-- Faith
R("MereChristianity", "Mere Christianity", "C. S. Lewis", 227, "faith", 4, "S")
R("TheScrewtapeLetters", "The Screwtape Letters", "C. S. Lewis", 160, "faith", 4, "S")
R("ThePowerOfPositiveThinking", "The Power of Positive Thinking", "Norman Vincent Peale", 276, "faith", 2, "S")
R("TheRoadLessTraveled", "The Road Less Traveled", "M. Scott Peck", 316, "faith", 3, "S")
R("SiddharthaBook", "Siddhartha", "Hermann Hesse", 152, "faith", 4, "S")
R("TheTaoOfPooh", "The Tao of Pooh", "Benjamin Hoff", 158, "faith", 3, "S")

-- Fringe
R("ChariotsOfTheGods", "Chariots of the Gods?", "Erich von Daniken", 192, "fringe", 2, "S")
R("TheBermudaTriangle", "The Bermuda Triangle", "Charles Berlitz", 203, "fringe", 1, "S")
R("CommunionBook", "Communion", "Whitley Strieber", 299, "fringe", 2, "S")
R("TheCelestineProphecy", "The Celestine Prophecy", "James Redfield", 246, "fringe", 2, "H")
R("OutOnALimb", "Out on a Limb", "Shirley MacLaine", 367, "fringe", 1, "S")

-- Self-Help & Lifestyle
R("HowToWinFriendsAndInfluencePeople", "How to Win Friends and Influence People", "Dale Carnegie", 291, "selfhelp", 3, "S")
R("The7HabitsOfHighlyEffectivePeople", "The 7 Habits of Highly Effective People", "Stephen R. Covey", 340, "selfhelp", 3, "S")
R("MenAreFromMars", "Men Are from Mars, Women Are from Venus", "John Gray", 286, "selfhelp", 2, "H")
R("IronJohn", "Iron John", "Robert Bly", 268, "selfhelp", 2, "S")
R("WomenWhoRunWithTheWolves", "Women Who Run With the Wolves", "Clarissa Pinkola Estes", 520, "selfhelp", 3, "H")
R("TheJoyOfCooking", "Joy of Cooking", "Irma S. Rombauer", 915, "selfhelp", 4, "H")
R("DrAtkinsNewDietRevolution", "Dr. Atkins' New Diet Revolution", "Robert C. Atkins", 330, "selfhelp", 1, "H")

-- Science & Nature
R("ABriefHistoryOfTime", "A Brief History of Time", "Stephen Hawking", 198, "science", 4, "B")
R("Cosmos", "Cosmos", "Carl Sagan", 365, "science", 5, "B")
R("TheSelfishGene", "The Selfish Gene", "Richard Dawkins", 224, "science", 4, "S")
R("SilentSpring", "Silent Spring", "Rachel Carson", 368, "science", 5, "S")
R("DesertSolitaire", "Desert Solitaire", "Edward Abbey", 269, "science", 5, "S")
R("APilgrimAtTinkerCreek", "Pilgrim at Tinker Creek", "Annie Dillard", 271, "science", 4, "S")
R("Chaos", "Chaos: Making a New Science", "James Gleick", 352, "science", 4, "S")
R("TheDoubleHelix", "The Double Helix", "James D. Watson", 226, "science", 4, "S")
R("Longitude_NotYet", "Surely You're Joking, Mr. Feynman!", "Richard P. Feynman", 350, "science", 5, "S")
R("TheHotZoneNo_Soul", "The Soul of a New Machine", "Tracy Kidder", 293, "science", 4, "S")
R("MedicalMysteries", "The Man Who Mistook His Wife for a Hat", "Oliver Sacks", 233, "science", 5, "S")

-- Arts & Screen
R("Hitchcock", "Hitchcock", "Francois Truffaut", 368, "arts", 4, "S")
R("TheWaysOfSeeing", "Ways of Seeing", "John Berger", 166, "arts", 4, "S")
R("TheStoryOfArt", "The Story of Art", "E. H. Gombrich", 688, "arts", 5, "H")
R("AdventuresInTheScreenTrade", "Adventures in the Screen Trade", "William Goldman", 436, "arts", 4, "S")
R("HammerOfTheGods", "Hammer of the Gods", "Stephen Davis", 348, "arts", 3, "S")
R("NoOneHereGetsOutAlive", "No One Here Gets Out Alive", "Jerry Hopkins and Danny Sugerman", 387, "arts", 3, "S")
R("TheJazzBook", "Miles: The Autobiography", "Miles Davis with Quincy Troupe", 431, "arts", 4, "S")

-- Serious Reading
R("TheArtOfWar", "The Art of War", "Sun Tzu", 112, "serious", 4, "S")
R("ThePrince", "The Prince", "Niccolo Machiavelli", 140, "serious", 4, "S")
R("TheWealthOfNations", "The Wealth of Nations", "Adam Smith", 1264, "serious", 3, "H")
R("Meditations", "Meditations", "Marcus Aurelius", 254, "serious", 5, "S")
R("TheRepublic", "The Republic", "Plato", 416, "serious", 4, "S")
R("LiarsPoker", "Liar's Poker", "Michael Lewis", 249, "serious", 4, "S")
R("BarbariansAtTheGate", "Barbarians at the Gate", "Bryan Burrough and John Helyar", 528, "serious", 4, "S")
R("TheDeathAndLifeOfGreatAmericanCities", "The Death and Life of Great American Cities", "Jane Jacobs", 458, "serious", 4, "S")
R("InnocentsAbroad", "The Innocents Abroad", "Mark Twain", 651, "serious", 3, "S")
R("BlueHighways", "Blue Highways", "William Least Heat-Moon", 421, "serious", 4, "S")

-- overrides on the generated rows, by vanilla title key ------------------------
D.overrides = {
    -- comics the word list gets wrong
    DrApeBattlesAtomLizard = { family = "scifi" },
    DrApeJrGangExploresSpace = { family = "scifi" },
    GammaRadiationChild = { family = "scifi" },
    TeenSteelman = { family = "scifi" },
    TeenSurgeons = { family = "humor" },
    HisayosanDeathisLife = { family = "romance" },
    LassoLadyvsCthulhu = { family = "westerns" },
    LassoLadyFighttotheDeath = { family = "westerns" },
    CurseRyder = { family = "westerns" },
    DangerHorse = { family = "westerns" },
    Bricklayer = { family = "humor" },
    TheForeman = { family = "humor" },
    MonsterPresidents = { family = "humor" },
    TheStockbrokerDeadCatBounce = { family = "humor" },
    TheStockbrokerNewInvestments = { family = "humor" },
    RevengeoftheStockbroker = { family = "humor" },
    ToddlerPolice = { family = "humor" },
    -- a few notable picks
    AFarewelltoArms = { quality = 5 },
    AnnaKarenina = { quality = 5 },
    AdventuresofHuckleberryFinn = { quality = 5 },
    AttheMountainsofMadness = { quality = 5 },
    AllQuietontheWesternFront = { quality = 5 },
    AStudyinScarlet = { quality = 4 },
    Candide = { quality = 4 },
}
