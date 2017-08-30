// This file contains your Data Connector logic
section CalendarCreator;
 [DataSource.Kind="FiscalCalendarCreator", Publish="FiscalCalendarCreator.Publish"]
 shared Fiscal.CalendarCreator = Value.ReplaceType(FiscalCalendarCreator.Feed, ParamsFiscal);

ParamsFiscal =
   type function (
        InitialDate as ( type date meta[
        Documentation.FieldCaption = "Initial date",
        Documentation.FieldDescription = "Choose when your Calendar Table will start"]),
        EndDate as ( type date meta[
        Documentation.FieldCaption = "End date",
        Documentation.FieldDescription = "Choose the last date of your Calendar Table"]),
        ExampleYearEnd  as( type date meta[
        Documentation.FieldCaption = "Year-end Example",
        Documentation.FieldDescription = "Provide an example for the day (month and day combination) when your fiscal year ends"]),
        culture as( type text meta [
        Documentation.FieldCaption = "Select the Culture/Locale",
        Documentation.FieldDescription = "This will affect the columns that rely on the locale",
        Documentation.AllowedValues = Table.Column(LanguagesAvailable(), "Language") ])) 
        as table
;
FiscalCalendarCreator.Feed = ( InitialDate as date, EndDate as date, ExampleYearEnd as date, culture as text) =>
  let
     Locale =  LanguagesAvailable(){[Language=culture]}[CiLocale String],
    StartDate= InitialDate,
    AdjustedFirstYearEnd = #date(Date.Year(StartDate), Date.Month(ExampleYearEnd),Date.Day(ExampleYearEnd)),
    FiscalStartDate = if AdjustedFirstYearEnd < StartDate then AdjustedFirstYearEnd+#duration(1,0,0,0) else Date.AddYears(AdjustedFirstYearEnd+#duration(1,0,0,0),-1),
    DateRanges = Table.FromRecords(List.Generate( ()=>
[FiscalStartDate= FiscalStartDate, FiscalEndDate=AdjustedFirstYearEnd],
each [FiscalStartDate] <= EndDate,
each [FiscalStartDate= [FiscalEndDate]+#duration(1,0,0,0), FiscalEndDate= Date.AddYears([FiscalEndDate],1)])),
    #"Changed Type" = Table.TransformColumnTypes(DateRanges,{{"FiscalStartDate", type date}, {"FiscalEndDate", type date}}),
    #"Inserted Year" = Table.AddColumn(#"Changed Type", "Fiscal Year", each Date.Year([FiscalEndDate]), type number),
    Custom1 = Table.AddColumn(#"Inserted Year", "FYName", each "FY"&Text.End(Text.From([Fiscal Year], "en-US"), 2), type text),
    #"Invoked Custom Function" = Table.AddColumn(Custom1, "fxFiscal", each FiscalYear([FiscalStartDate], [FiscalEndDate], Locale)),
    #"Expanded fxFiscal" = Table.ExpandTableColumn(#"Invoked Custom Function", "fxFiscal", {"DateKey", "FiscalMonth", "FiscalQuarter", "FiscalDay", "FiscalWeek", "Calendar Year", "Calendar Quarter", "Calendar Month", "Calendar Month Name", "Week of Calendar Year", "Day", "Day of Calendar Year", "Day Name"}, {"DateKey", "FiscalMonth", "FiscalQuarter", "FiscalDay", "FiscalWeek", "Calendar Year", "Calendar Quarter", "Calendar Month", "Calendar Month Name", "Week of Calendar Year", "Day", "Day of Calendar Year", "Day Name"}),
    FromStartDate= Table.SelectRows(#"Expanded fxFiscal", each [DateKey] >= StartDate and [DateKey] <=  EndDate),
#"Changed Type1" = Table.TransformColumnTypes(FromStartDate,{{"FiscalMonth", Int64.Type}, {"FiscalQuarter", Int64.Type}, {"FiscalDay", Int64.Type}, {"FiscalWeek", Int64.Type}, {"Calendar Year", Int64.Type}, {"Calendar Quarter", Int64.Type}, {"Calendar Month", Int64.Type}, {"Week of Calendar Year", Int64.Type}, {"Day", Int64.Type}, {"Day of Calendar Year", Int64.Type}, {"Day Name", type text}, {"Calendar Month Name", type text}, {"DateKey", type date}})
in
    #"Changed Type1";

 [DataSource.Kind="CalendarCreator", Publish="CalendarCreator.Publish"]
shared Week.CalendarCreator = Value.ReplaceType(CalendarCreator.Feed, Params);

Params =
   type function (
        StartWeekOfYear as ( type date meta[
        Documentation.FieldCaption = "First Date of Week-Year",
        Documentation.FieldDescription = "First Date of the First Week of the First Year of your Calendar"]),
        EndDate as ( type date meta[
        Documentation.FieldCaption = "End date",
        Documentation.FieldDescription = "Choose the last date of your Calendar Table"]),
        calendartype  as( type text meta[
        Documentation.FieldCaption = "Choose your Calendar Type",
        Documentation.FieldDescription = "Please select from the available Calendar Type options",
        Documentation.AllowedValues = Table.Column(CalendarTypes(),"Type") ]),
        culture as( type text meta [
        Documentation.FieldCaption = "Select the Culture/Locale",
        Documentation.FieldDescription = "This will affect the columns that rely on the locale",
        Documentation.AllowedValues = Table.Column(LanguagesAvailable(), "Language") ])) 
        as table
;

CalendarCreator.Feed = (StartWeekOfYear as date, EndDate as date, calendartype as text, culture as text) => 
 let
    MaxDate = EndDate,
    Locale =  LanguagesAvailable(){[Language=culture]}[CiLocale String],
    Source = List.Generate( ()=>
 [Result= CalendarTable(StartWeekOfYear, calendartype, Locale), FirstWeekOfYear = StartWeekOfYear],
each [FirstWeekOfYear] <= MaxDate,
each [Result = CalendarTable(FirstWeekOfYear,calendartype, Locale), FirstWeekOfYear = [FirstWeekOfYear]+#duration(364,0,0,0)],
each [Result]),
    Custom1 = Table.Buffer(Table.Combine(Source)),
    DayID = Table.AddIndexColumn(Custom1, "DayID", 1, 1),
    WeekID = Table.AddColumn(DayID, "WeekID", each Number.RoundUp([DayID]/7), type number),
    QuarterID = Table.AddColumn(WeekID, "QuarterID", each Number.RoundUp([DayID]/91), type number),
    YearID = Table.AddColumn(QuarterID, "YearID", each Number.RoundUp([DayID]/364), type number),
    #"Grouped Rows" = Table.Group(YearID, {"Year", "MonthOfYear"}, {{"Data", each _, type table}}),
    MonthID = Table.AddIndexColumn(#"Grouped Rows", "MonthID", 1, 1),
    #"Removed Columns" = Table.RemoveColumns(MonthID,{"Year", "MonthOfYear"}),
    #"Added Custom" = Table.AddColumn(#"Removed Columns", "Custom", each Table.AddColumn( [Data], "MonthID", (m) => [MonthID], type number)),
    Custom = Table.Combine(#"Added Custom"[Custom]),
    #"Filtered Rows" = Table.SelectRows(Custom, each [DateKey] <= MaxDate)
in
    #"Filtered Rows";


CalendarTable = (StartWeekOfYear as date, calendartype as text, culture as text) => 
let
    Source = List.Dates( StartWeekOfYear, 4, #duration(91,0,0,0)),
    CalendarSet1= CalendarTypes(){[Type=calendartype]}[Set1],
    CalendarSet2= CalendarTypes(){[Type=calendartype]}[Set2],
    CalendarSet3= CalendarTypes(){[Type=calendartype]}[Set3],
    QuarterStartDate = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    Year = Table.AddColumn(QuarterStartDate, "Year", each Date.Year(StartWeekOfYear)),
    EndOfQuarter = Table.AddColumn(Year, "Custom", each [Column1]+#duration(90,0,0,0)),
    QuarterNumber = Table.AddIndexColumn(EndOfQuarter, "QuarterOfYear", 1, 1),
    DataTypeToQuarterStartDate = Table.TransformColumnTypes(QuarterNumber,{{"Column1", type date}, {"Custom", type date}}),
    RenamingToQuarterStartDate = Table.RenameColumns(DataTypeToQuarterStartDate,{{"Column1", "StartOfQuarter"}, {"Custom", "EndOfQuarter"}}),
    WeekSets = Table.AddColumn(RenamingToQuarterStartDate, "StartOfWeek", each Table.FromRecords({ [Set=1, Dates=Table.FromList(List.Dates( [StartOfQuarter], CalendarSet1, #duration(7,0,0,0)),  Splitter.SplitByNothing(), null, null, ExtraValues.Error)],
  [Set=2, Dates= Table.FromList(List.Dates( [StartOfQuarter]+#duration(7*CalendarSet1,0,0,0), CalendarSet2, #duration(7,0,0,0)),  Splitter.SplitByNothing(), null, null, ExtraValues.Error)],
  [Set=3, Dates= Table.FromList(List.Dates( [StartOfQuarter]+#duration(7*(CalendarSet1+CalendarSet2),0,0,0), CalendarSet3, #duration(7,0,0,0)),  Splitter.SplitByNothing(), null, null, ExtraValues.Error)] 
})),
    ExpandingWeekSets = Table.ExpandTableColumn(WeekSets, "StartOfWeek", {"Set", "Dates"}, {"Set", "Dates"}),
    MonthNumber = Table.AddIndexColumn(ExpandingWeekSets, "MonthOfYear", 1, 1),
    MonthOfQuarter = Table.AddColumn(MonthNumber, "MonthOfQuarter", each Number.Mod([MonthOfYear]-1, 4)+1, type number),
    WeekOfMonth = Table.AddColumn(MonthOfQuarter, "Custom.1", each Table.AddIndexColumn( 
Table.TransformColumnTypes([Dates],{{"Column1", Date.Type}}), "WeekOfMonth", 1, 1)),
    #"Removing UnnecesaryColumns" = Table.RemoveColumns(WeekOfMonth,{"Dates"}),
    #"Duplicated Column" = Table.DuplicateColumn(#"Removing UnnecesaryColumns", "Custom.1", "Custom.1 - Copy"),
    StartOfMonth = Table.AggregateTableColumn(#"Duplicated Column", "Custom.1 - Copy", {{"Column1", List.Min, "StartOfMonth"}, {"Column1", List.Max, "LastWeekOfMonth"}}),
    EndOfMonth = Table.AddColumn(StartOfMonth, "EndOfMonth", each [LastWeekOfMonth]+#duration(6,0,0,0), Date.Type),
    RemoveLastWeekOfMonth = Table.RemoveColumns(EndOfMonth,{"LastWeekOfMonth"}),
    ExpandWeekData = Table.ExpandTableColumn(RemoveLastWeekOfMonth, "Custom.1", {"Column1", "WeekOfMonth"}, {"Column1", "WeekOfMonth"}),
    RenamingToStartOfWeek = Table.RenameColumns(ExpandWeekData,{{"Column1", "StartOfWeek"}}),
    SortedByStartOfWeek = Table.Sort(RenamingToStartOfWeek,{{"StartOfWeek", Order.Ascending}}),
    DateKey = Table.AddColumn(SortedByStartOfWeek, "DateKey", each Table.AddIndexColumn( 
Table.FromList(List.Dates( [StartOfWeek], 7, #duration(1,0,0,0)),  Splitter.SplitByNothing(), null, null, ExtraValues.Error),"DayOfWeek", 1, 1)),
    WeekOfYear = Table.AddIndexColumn(DateKey, "WeekOfYear", 1, 1),
    WeekOfQuarter = Table.AddColumn(WeekOfYear, "WeekOfQuarter", each Number.Mod([WeekOfYear]-1, 13)+1, type number),
    #"Expanded DateKey" = Table.ExpandTableColumn(WeekOfQuarter, "DateKey", {"Column1", "DayOfWeek"}, {"DateKey", "DayOfWeek"}),
    DayOfYear = Table.AddIndexColumn(#"Expanded DateKey", "DayOfYear", 1, 1),
    DataTypes = Table.TransformColumnTypes(DayOfYear,{{"Year", Int64.Type}, {"StartOfWeek", type date}, {"DateKey", type date}, {"Set", Int64.Type}, {"WeekOfMonth", Int64.Type}, {"DayOfWeek", Int64.Type}, {"StartOfMonth", type date}}),
    EndOfWeek = Table.AddColumn(DataTypes, "EndOfWeek", each [StartOfWeek]+#duration(6,0,0,0), Date.Type),
    DateISO = Table.AddColumn(EndOfWeek, "DateISO", each Date.ToText([DateKey], "yyyy-MM-dd"), type text),
    DateInt = Table.AddColumn(DateISO, "DateInt", each Date.Year([DateKey]) * 10000 + Date.Month([DateKey]) * 100 + Date.Day([DateKey]), type number),
    DateLong = Table.AddColumn(DateInt, "DateLong", each Date.ToText([DateKey], "MMMM dd, yyyy",culture), type text),
    DateMedium = Table.AddColumn(DateLong, "DateMedium", each Date.ToText([DateKey], "MMM dd, yyyy",culture), type text),
    Day_Long = Table.AddColumn(DateMedium, "Day_Long", each Date.ToText([DateKey], "dddd",culture), type text),
    Day_Short = Table.AddColumn(Day_Long, "Day_Short", each Date.ToText([DateKey], "ddd",culture), type text),
    DayOfQuarter = Table.AddColumn(Day_Short, "DayOfQuarter", each Number.Abs(Duration.Days([StartOfQuarter] - [DateKey]))+1, Int64.Type),
    StartOfYear = Table.AddColumn(DayOfQuarter, "StartOfYear", each List.Min(Table.Column(DayOfQuarter, "DateKey")), Date.Type),
    EndOfYear = Table.AddColumn(StartOfYear, "EndOfYear", each List.Max(Table.Column(StartOfYear, "DateKey")), Date.Type),
    DayOfMonth = Table.AddColumn(EndOfYear, "DayOfMonth", each Number.Abs(Duration.Days([StartOfMonth] - [DateKey]))+1, Int64.Type),
    #"Removed Columns" = Table.RemoveColumns(DayOfMonth,{"Set"}),
    #"Reordered Columns" =  Table.ReorderColumns(#"Removed Columns",{"DateInt", "DateISO", "DateKey", "Day_Short", "Day_Long", "DateMedium", "DateLong", "Year", "QuarterOfYear", "MonthOfQuarter", "MonthOfYear", "WeekOfMonth", "WeekOfQuarter", "WeekOfYear", "DayOfWeek", "DayOfMonth", "DayOfQuarter", "DayOfYear", "StartOfWeek", "EndOfWeek", "StartOfMonth", "EndOfMonth", "StartOfQuarter", "EndOfQuarter", "StartOfYear", "EndOfYear"})
in
    #"Reordered Columns";

 LanguagesAvailable = () as table =>
     let
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("XVLRbqMwEPyVKE+tVD4iJBBoEBdhyElX9WET9hIrxO4Zu5H69Wd73Op6T7Az652dsV9elqvfRl6J1Lx8Wq7K5euThwwd5SnUXaxzmv84Xjzg++iJYgDBExk3S1IeywtgbjqTSdA2QmuyNEVgvQJwkYpnPzH8UBj4q8rW7XeuJ3knlcj+J0ijyWJ2hd3WH3y6hMkilhtScg71BkobZyPdNrEs1Hny/OJha5jsIjfSkowaRZtt8+89g5KWx4WwZHlOPQNkitlqhT2KPiIlsdF+b4+UP4BIlXYpawCGVVym7LKy+wfyOZCiUcKtZ1NMWza3qLFBtH5pvgZJmKn4aPgeogBdOfWVfIULqk/+htQYL7PG6rUatQ8YbTUyr/39JABunumNFNw8Y5ed9omFjh3cNWTfcaQ5AJD24iiF0mBMq82dz4BanNvrCaHsm1Qb684OWvv+P8y/OUMfcnqMZJYjtU7fPoU6TO3cnBx1MC7YHAEInBGTfqcQnth91ZyGCKwi3j4fTyGyAmmJO4/ABGz2F5K+6itUzlxB95AZrsY/KIwdoHSQbBXd4PDgn8LrXw==", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type text) meta [Serialized.Text = true]) in type table [Language = _t, #"CiLocale String" = _t]),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Language", type text}, {"CiLocale String", type text}}),
    #"Lowercased Text" = Table.TransformColumns(#"Changed Type",{{"CiLocale String", Text.Lower}})
in
    #"Lowercased Text";

CalendarTypes= () as table =>
    let
    Source = Table.FromRecords({
    [Type="4-4-5",Set1=4,Set2=4,Set3=5],
    [Type="4-5-4",Set1=4,Set2=5,Set3=4],
    [Type="5-4-4",Set1=5,Set2=4,Set3=4]}),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Type", type text}, {"Set1", Int64.Type}, {"Set2", Int64.Type}, {"Set3", Int64.Type}})
in
    #"Changed Type";

FiscalYear = (StartDate as date, EndDate as date, culture as text) =>
 let
    FiscalYearDates = List.Dates(StartDate, Number.From(EndDate) - Number.From(StartDate)+1, #duration(1,0,0,0)),
    ToTable = Table.FromList(FiscalYearDates, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Inserted Month" = Table.AddColumn(ToTable, "Month", each Date.Year([Column1])*100+Date.Month([Column1]), type number),
    #"Grouped Rows" = Table.Group(#"Inserted Month", {"Month"}, {{"Data", each _, type table}}),
    #"Sorted Rows" = Table.Sort(#"Grouped Rows",{{"Month", Order.Ascending}}),
    #"Removed Columns" = Table.RemoveColumns(#"Sorted Rows",{"Month"}),
    FiscalMonth = Table.AddIndexColumn(#"Removed Columns", "FiscalMonth", 1, 1),
    FiscalQuarter = Table.AddColumn(FiscalMonth, "FiscalQuarter", each Number.IntegerDivide([FiscalMonth]-1, 3)+1, Int64.Type),
    #"Expanded Data" = Table.ExpandTableColumn(FiscalQuarter, "Data", {"Column1"}, {"Column1"}),
    FiscalDay = Table.AddIndexColumn(#"Expanded Data", "FiscalDay", 1, 1),
    FiscalWeek = Table.AddColumn(FiscalDay, "FiscalWeek", each Number.IntegerDivide([FiscalDay]-1, 7)+1, Int64.Type),
    #"Changed Type" = Table.TransformColumnTypes(FiscalWeek,{{"Column1", type date}, {"FiscalMonth", Int64.Type}, {"FiscalDay", Int64.Type}}),
    #"Renamed Columns" = Table.RenameColumns(#"Changed Type",{{"Column1", "DateKey"}}),
    #"Inserted Year" = Table.AddColumn(#"Renamed Columns", "Calendar Year", each Date.Year([DateKey]), type number),
    #"Inserted Quarter" = Table.AddColumn(#"Inserted Year", "Calendar Quarter", each Date.QuarterOfYear([DateKey]), type number),
    #"Inserted Month1" = Table.AddColumn(#"Inserted Quarter", "Calendar Month", each Date.Month([DateKey]), type number),
    #"Inserted Month Name" = Table.AddColumn(#"Inserted Month1", "Calendar Month Name", each Date.MonthName([DateKey], culture), type text),
    #"Inserted Week of Year" = Table.AddColumn(#"Inserted Month Name", "Week of Calendar Year", each Date.WeekOfYear([DateKey]), type number),
    #"Inserted Day" = Table.AddColumn(#"Inserted Week of Year", "Day", each Date.Day([DateKey]), type number),
    #"Inserted Day of Year" = Table.AddColumn(#"Inserted Day", "Day of Calendar Year", each Date.DayOfYear([DateKey]), type number),
    #"Inserted Day Name" = Table.AddColumn(#"Inserted Day of Year", "Day Name", each Date.DayOfWeekName([DateKey], culture), type text)
in
    #"Inserted Day Name";
// Data Source Kind description
CalendarCreator = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Implicit = []
    ]
];

FiscalCalendarCreator = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Implicit = []
    ]
];


// Data Source UI publishing description
CalendarCreator.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { "Week-based Calendar Creator", Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = CalendarCreator.Icons,
    SourceTypeImage = CalendarCreator.Icons
];

FiscalCalendarCreator.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { "Fiscal Calendar Creator", Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = CalendarCreator.Icons,
    SourceTypeImage = CalendarCreator.Icons
];

CalendarCreator.Icons = [
    Icon16 = { Extension.Contents("CalendarCreator16.png"), Extension.Contents("CalendarCreator20.png"), Extension.Contents("CalendarCreator24.png"), Extension.Contents("CalendarCreator32.png") },
    Icon32 = { Extension.Contents("CalendarCreator32.png"), Extension.Contents("CalendarCreator40.png"), Extension.Contents("CalendarCreator48.png"), Extension.Contents("CalendarCreator64.png") }
];