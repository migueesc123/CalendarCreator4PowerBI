// This file contains your Data Connector logic
section CalendarCreator;
 [DataSource.Kind="Fiscal5253CalendarCreator", Publish="Fiscal5253CalendarCreator.Publish"]
shared  Fiscal5253.CalendarCreator = Value.ReplaceType(Fiscal5253CalendarCreator.Feed, ParamsFiscal5253);

Fiscal5253CalendarCreator.Feed = (StartDate as date, EndDate as date, Month as text, endtype as text, Weekday as text, calendartype as text, culture as text)=>
let
       month= Months(){[Month=Month]}[MonthNumber],
       DayOfWeek= WeekDays(){[WeekDay=Weekday]}[DayNumber],
      Locale =  LanguagesAvailable(){[Language=culture]}[CiLocale String],
  CalendarSet1= CalendarTypes(){[Type=calendartype]}[Set1],
    CalendarSet2= CalendarTypes(){[Type=calendartype]}[Set2],
    CalendarSet3= CalendarTypes(){[Type=calendartype]}[Set3],
 AdjustedYearStart = Date.Year(StartDate)-1,
Origen = List.Generate( ()=>   
 [Result= StartDate5253(Year,month,DayOfWeek), Year=AdjustedYearStart, StartDate=Result, EndDate=null], 
each [StartDate]<=EndDate, 
each [Result= StartDate5253(Year,month,DayOfWeek), Year=[Year]+1,StartDate=[Result],EndDate=StartDate5253(Year,month,DayOfWeek)-#duration(1,0,0,0)]),
    #"Convertida en tabla" = Table.FromList(Origen, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Se expandió Column1" = Table.ExpandRecordColumn(#"Convertida en tabla", "Column1", {"StartDate", "EndDate"}, {"StartDate", "EndDate"}),
    #"Filas filtradas" = Table.SelectRows(#"Se expandió Column1", each ([EndDate] <> null)),
    #"Resta de fecha insertada" = Table.AddColumn(#"Filas filtradas", "TotalDays", each Duration.Days( [EndDate] - [StartDate]), Int64.Type),
    #"Tipo cambiado" = Table.TransformColumnTypes(#"Resta de fecha insertada",{{"StartDate", type date}, {"EndDate", type date}}),
    #"Año insertado" = Table.AddColumn(#"Tipo cambiado", "Accounting Year", each Date.Year([EndDate]), type number),
    #"División entera insertada" = Table.AddColumn(#"Año insertado", "Total Weeks in Year", each Number.IntegerDivide([TotalDays], 7)+1, Int64.Type),
    #"Personalizada agregada" = Table.AddColumn(#"División entera insertada", "Quarter Start Date", each Table.FromList(List.Dates([StartDate], 
4,
#duration(91,0,0,0)) , Splitter.SplitByNothing(), null, null, ExtraValues.Error)),
    #"Personalizada agregada1" = Table.AddColumn(#"Personalizada agregada", "Personalizado", each Table.AddIndexColumn([Quarter Start Date], "Quarter", 1, 1)),
    #"Columnas quitadas" = Table.RemoveColumns(#"Personalizada agregada1",{"Quarter Start Date"}),
    #"Se expandió Personalizado" = Table.ExpandTableColumn(#"Columnas quitadas", "Personalizado", {"Column1", "Quarter"}, {"Column1", "Quarter"}),
    #"Columnas con nombre cambiado" = Table.RenameColumns(#"Se expandió Personalizado",{{"Column1", "StartOfQuarter"}}),
    #"Personalizada agregada2" = Table.AddColumn(#"Columnas con nombre cambiado", "EndOfQuarter", each if [Quarter] = 4 then [EndDate] else [StartOfQuarter]+#duration(90,0,0,0)),
    #"Personalizada agregada3" = Table.AddColumn(#"Personalizada agregada2", "Personalizado", each Table.FromRecords({ [Set=1, Dates=Table.FromList(List.Dates( [StartOfQuarter], CalendarSet1, #duration(7,0,0,0)),  Splitter.SplitByNothing(), null, null, ExtraValues.Error)],
  [Set=2, Dates= Table.FromList(List.Dates( [StartOfQuarter]+#duration(7*CalendarSet1,0,0,0), CalendarSet2, #duration(7,0,0,0)),  Splitter.SplitByNothing(), null, null, ExtraValues.Error)],
  [Set=3, Dates= Table.FromList(List.Dates( [StartOfQuarter]+#duration(7*(CalendarSet1+CalendarSet2),0,0,0),  if [Quarter]=4 then [Total Weeks in Year]-52+CalendarSet3 else CalendarSet3, #duration(7,0,0,0)),  Splitter.SplitByNothing(), null, null, ExtraValues.Error)] 
})),
    #"Se expandió Personalizado1" = Table.ExpandTableColumn(#"Personalizada agregada3", "Personalizado", {"Set", "Dates"}, {"Set", "Dates"}),
    #"Índice agregado" = Table.AddIndexColumn(#"Se expandió Personalizado1", "Índice", 1, 1),
    #"Módulo insertado" = Table.AddColumn(#"Índice agregado", "MonthNumber", each Number.Mod([Índice]-1, 12)+1, type number),
    #"Columnas quitadas1" = Table.RemoveColumns(#"Módulo insertado",{"Índice"}),
    #"Personalizada agregada4" = Table.AddColumn(#"Columnas quitadas1", "Personalizado", each Table.AddIndexColumn( 
Table.TransformColumnTypes([Dates],{{"Column1", Date.Type}}), "WeekOfMonth", 1, 1)),
    #"Columnas quitadas2" = Table.RemoveColumns(#"Personalizada agregada4",{"Dates"}),
    #"Columna duplicada" = Table.DuplicateColumn(#"Columnas quitadas2", "Personalizado", "Personalizado - Copia"),
    StartOfMonth = Table.AggregateTableColumn(#"Columna duplicada", "Personalizado - Copia", {{"Column1", List.Min, "StartOfMonth"}, {"Column1", List.Max, "LastWeekOfMonth"}}),
    EndOfMonth = Table.AddColumn(StartOfMonth, "EndOfMonth", each [LastWeekOfMonth]+#duration(6,0,0,0), Date.Type),
    #"Columnas quitadas3" = Table.RemoveColumns(EndOfMonth,{"LastWeekOfMonth"}),
    #"Se expandió Personalizado2" = Table.ExpandTableColumn(#"Columnas quitadas3", "Personalizado", {"Column1", "WeekOfMonth"}, {"Column1", "WeekOfMonth"}),
    #"Columnas con nombre cambiado1" = Table.RenameColumns(#"Se expandió Personalizado2",{{"Column1", "StartOfWeek"}}),
    #"Filas ordenadas" = Table.Sort(#"Columnas con nombre cambiado1",{{"StartOfWeek", Order.Ascending}}),
    #"Filas agrupadas" = Table.Group(#"Filas ordenadas", {"Accounting Year"}, {{"AllRows", each _, type table}}),
    #"Personalizada agregada5" = Table.AddColumn(#"Filas agrupadas", "Personalizado", each Table.AddIndexColumn([AllRows], "WeekOfYear", 1, 1)),
    #"Columnas quitadas4" = Table.RemoveColumns(#"Personalizada agregada5",{"AllRows"}),
    #"Se expandió Personalizado3" = Table.ExpandTableColumn(#"Columnas quitadas4", "Personalizado", {"StartDate", "EndDate", "TotalDays", "Total Weeks in Year", "StartOfQuarter", "Quarter", "EndOfQuarter", "Set", "MonthNumber", "StartOfWeek", "WeekOfMonth", "StartOfMonth", "EndOfMonth", "WeekOfYear"}, {"StartDate", "EndDate", "TotalDays", "Total Weeks in Year", "StartOfQuarter", "Quarter", "EndOfQuarter", "Set", "MonthNumber", "StartOfWeek", "WeekOfMonth", "StartOfMonth", "EndOfMonth", "WeekOfYear"}),
    #"Personalizada agregada6" = Table.AddColumn(#"Se expandió Personalizado3", "EndOfWeek", each [StartOfWeek]+#duration(6,0,0,0)),
    #"Personalizada agregada7" = Table.AddColumn(#"Personalizada agregada6", "DateKey", each Table.AddIndexColumn( 
Table.FromList( List.Dates([StartOfWeek],7,#duration(1,0,0,0)), Splitter.SplitByNothing(), null, null, ExtraValues.Error),"DayOfWeek", 1, 1)),
    #"Se expandió DateKey" = Table.ExpandTableColumn(#"Personalizada agregada7", "DateKey", {"Column1", "DayOfWeek"}, {"DateKey", "DayOfWeek"}),
    #"Filas agrupadas1" = Table.Group(#"Se expandió DateKey", {"Accounting Year"}, {{"AllRows", each _, type table}}),
    #"Personalizada agregada8" = Table.AddColumn(#"Filas agrupadas1", "DayOfYear", each Table.AddIndexColumn([AllRows], "DayOfYear", 1, 1)),
    #"Columnas quitadas5" = Table.RemoveColumns(#"Personalizada agregada8",{"AllRows"}),
    #"Se expandió DayOfYear" = Table.ExpandTableColumn(#"Columnas quitadas5", "DayOfYear", {"StartDate", "EndDate", "TotalDays", "Total Weeks in Year", "StartOfQuarter", "Quarter", "EndOfQuarter", "Set", "MonthNumber", "StartOfWeek", "WeekOfMonth", "StartOfMonth", "EndOfMonth", "WeekOfYear", "EndOfWeek", "DateKey", "DayOfWeek", "DayOfYear"}, {"StartDate", "EndDate", "TotalDays", "Total Weeks in Year", "StartOfQuarter", "Quarter", "EndOfQuarter", "Set", "MonthNumber", "StartOfWeek", "WeekOfMonth", "StartOfMonth", "EndOfMonth", "WeekOfYear", "EndOfWeek", "DateKey", "DayOfWeek", "DayOfYear"}),
    #"Columnas con nombre cambiado2" = Table.RenameColumns(#"Se expandió DayOfYear",{{"StartDate", "YearStartDate"}, {"EndDate", "YearEndDate"}, {"TotalDays", "TotalDaysInYear"}, {"Total Weeks in Year", "TotalWeeksInYear"}, {"Quarter", "QuarterOfYear"}}),
    #"Columnas reordenadas" = Table.ReorderColumns(#"Columnas con nombre cambiado2",{"DateKey", "Accounting Year", "YearStartDate", "YearEndDate", "TotalDaysInYear", "TotalWeeksInYear", "StartOfQuarter", "QuarterOfYear", "EndOfQuarter", "Set", "MonthNumber", "StartOfMonth", "EndOfMonth", "StartOfWeek", "EndOfWeek", "DayOfYear", "WeekOfYear", "WeekOfMonth", "DayOfWeek"}),
    #"Año insertado1" = Table.AddColumn(#"Columnas reordenadas", "CalendarYear", each Date.Year([DateKey]), type number),
    #"Mes insertado" = Table.AddColumn(#"Año insertado1", "Mes", each Date.Month([DateKey]), type number),
    #"Columnas con nombre cambiado3" = Table.RenameColumns(#"Mes insertado",{{"Mes", "CalendarMonth"}}),
    #"Nombre del mes insertado" = Table.AddColumn(#"Columnas con nombre cambiado3", "CalendarMonthName", each Date.MonthName([DateKey], Locale), type text),
    #"Nombre del día insertado" = Table.AddColumn(#"Nombre del mes insertado", "WeekDayName", each Date.DayOfWeekName([DateKey],Locale), type text),
    DateISO = Table.AddColumn(#"Nombre del día insertado"  , "DateISO", each Date.ToText([DateKey], "yyyy-MM-dd"), type text),
    DateInt = Table.AddColumn(DateISO, "DateInt", each Date.Year([DateKey]) * 10000 + Date.Month([DateKey]) * 100 + Date.Day([DateKey]), type number),
    DateLong = Table.AddColumn(DateInt, "DateLong", each Date.ToText([DateKey], "MMMM dd, yyyy",Locale), type text),
    DateMedium = Table.AddColumn(DateLong, "DateMedium", each Date.ToText([DateKey], "MMM dd, yyyy",Locale), type text),
    Day_Long = Table.AddColumn(DateMedium, "Day_Long", each Date.ToText([DateKey], "dddd",Locale), type text),
    Day_Short = Table.AddColumn(Day_Long, "Day_Short", each Date.ToText([DateKey], "ddd",Locale), type text),
    #"Columnas reordenadas1" = Table.ReorderColumns(Day_Short,{"DateKey", "Accounting Year", "YearStartDate", "YearEndDate", "TotalDaysInYear", "TotalWeeksInYear", "StartOfQuarter", "EndOfQuarter", "QuarterOfYear", "Set", "MonthNumber", "StartOfMonth", "EndOfMonth", "StartOfWeek", "EndOfWeek", "DayOfYear", "WeekOfYear", "WeekOfMonth", "DayOfWeek", "CalendarYear", "CalendarMonth", "CalendarMonthName", "WeekDayName", "DateISO", "DateInt", "DateLong", "DateMedium", "Day_Long", "Day_Short"}),
    #"Tipo cambiado1" = Table.TransformColumnTypes(#"Columnas reordenadas1",{{"DayOfWeek", Int64.Type}, {"WeekOfMonth", Int64.Type}, {"WeekOfYear", Int64.Type}, {"DayOfYear", Int64.Type}, {"EndOfWeek", type date}, {"StartOfWeek", type date}, {"EndOfMonth", type date}, {"StartOfMonth", type date}, {"MonthNumber", Int64.Type}, {"Set", Int64.Type}, {"QuarterOfYear", Int64.Type}, {"EndOfQuarter", type date}, {"StartOfQuarter", type date}, {"YearEndDate", type date}, {"YearStartDate", type date}, {"DateKey", type date}, {"TotalDaysInYear", Int64.Type}, {"TotalWeeksInYear", Int64.Type}}),
    #"Columnas quitadas6" = Table.RemoveColumns(#"Tipo cambiado1",{"Set"}),
    Filter= Table.SelectRows(#"Columnas quitadas6", each [DateKey] >= StartDate and [DateKey] <= EndDate)
in
    Filter;

ParamsFiscal5253 =
   type function (
        InitialDate as ( type date meta[
        Documentation.FieldCaption = "Initial date",
        Documentation.FieldDescription = "Choose when your Calendar Table will start"]),
        EndDate as ( type date meta[
        Documentation.FieldCaption = "End date",
        Documentation.FieldDescription = "Choose the last date of your Calendar Table"]),
        Month as( type text meta [
        Documentation.FieldCaption = "Fiscal Year Month End",
        Documentation.FieldDescription = "Select the Month when your Fiscal Year ends",
        Documentation.AllowedValues = Table.Column(Months(), "Month") ]),
        endtype as( type text meta [
        Documentation.FieldCaption = "Last or Nearest?",
        Documentation.FieldDescription = "Will your calendar end on the last weekday of the end month or on the nearest weekday to the end of the month?",
        Documentation.AllowedValues = {"Last weekday", "Nearest Weekday to EndDate", "Last Date of Month"}]),
        Weekday as( type text meta [
        Documentation.FieldCaption = "Start of your Week",
        Documentation.FieldDescription = "Select on what day your week starts",
        Documentation.AllowedValues = Table.Column(WeekDays(), "WeekDay") ]),
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
    MonthOfQuarter = Table.AddColumn(MonthNumber, "MonthOfQuarter", each Number.Mod([MonthOfYear]-1, 3)+1, type number),
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
    Source = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("XVJdb6MwEPwrUZ5aqfwISCDQIBphyElX9WETfIkVYrf+aKT++rM9bnW5J9iZ9e7O7L6+LvM/WlyIpFk+LfNq+fbkIU0HcQxxH+OCzIfjiwd8Hz1RjiD4TNoZQdJjRQnMzSfSCdpEaEWW5giscgBnIbnxFcMPhYK/62zV3XMDiRvJRA6/QGpFFrVrzLb64sdzqMxiuCYpTIjX6LR2NtJdG8NSnmbPLx5yZ6ymWcTmZZfl4z2/0ZzsotDCkpApZ1Pc54xSWD4tmCXLTcoZMUZprJKYsxwiUhHXyuvySPUCRMg0a9UA0FzGYas+q/p/IO8TSZoE3PBssnHD9TX2WMN6PzS/hJYQW/OD5rdgFejayZ/N1NDbHP0G5RSX3WD0Rk7KLwBpDXbS2GBVBKDmmd5JQs0zZtkq71jI2EJdS/YTT9o9AGHPjpIpLcp0St/4CVCHdzs1w5Rdm2Jt3cmh1274D/M3qelLzI+RzAq41qvrd6MeVXtnkqIewhnXBwAMb9isPimYx7Y/MU9FGEZh79/HVbKshFvsxidgDDKHMwkfDTUipy+gB7QZL9ofFMqO6LQX3Eq6QuHen8LbXw==", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type text) meta [Serialized.Text = true]) in type table [Language = _t, #"CiLocale String" = _t]),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Language", type text}, {"CiLocale String", type text}}),
    #"Lowercased Text" = Table.TransformColumns(#"Changed Type",{{"CiLocale String", Text.Lower}})
in
    #"Lowercased Text";

WeekDays = () as table =>
    let
    Origen = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("i45W8s3PS0msVNJRMlSK1YlWCilNLYbwjcD88NSUPJiIMURFRmkRVMAELOBWlAnhmoK5wYklpUUQATOIQCnUBgOl2FgA", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type text) meta [Serialized.Text = true]) in type table [WeekDay = _t, DayNumber = _t]),
    #"Tipo cambiado" = Table.TransformColumnTypes(Origen,{{"WeekDay", type text}, {"DayNumber", Int64.Type}})
in
    #"Tipo cambiado";

 Months= () as table =>
let
    Origen = Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("i45W8krMK00sqlTSUTJUitWJVnJLTSqCChiBBXwTi5IzgDxjMM+xoCgzB8gzgcqB1JmC2V6lealAjhmUkwOSMYfoKU0vLS4Bci3A3ODUgpLU3KTUIqCIJVjEP7kkH8I3NAAL+OWXwVQYQpzlkpoMFwG6KxYA", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type text) meta [Serialized.Text = true]) in type table [Month = _t, MonthNumber = _t]),
    #"Tipo cambiado" = Table.TransformColumnTypes(Origen,{{"Month", type text}, {"MonthNumber", Int64.Type}})
in
    #"Tipo cambiado";

CalendarTypes= () as table =>
    let
    Source = Table.FromRecords({
    [Type="4-4-5",Set1=4,Set2=4,Set3=5],
    [Type="4-5-4",Set1=4,Set2=5,Set3=4],
    [Type="5-4-4",Set1=5,Set2=4,Set3=4]}),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Type", type text}, {"Set1", Int64.Type}, {"Set2", Int64.Type}, {"Set3", Int64.Type}})
in
    #"Changed Type";

StartDate5253 = (Year,Month,Weekday) =>
let
    Personalizado1 = List.Dates(#date(Year,Month,1), Number.From( Date.EndOfMonth(#date(Year,Month,1))) - Number.From(#date(Year,Month,1))+1, #duration(1,0,0,0)),
    #"Convertida en tabla" = Table.FromList(Personalizado1, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Día de la semana insertado" = Table.AddColumn(#"Convertida en tabla", "Día de la semana", each Date.DayOfWeek([Column1], Weekday), type number),
#"Filas filtradas" = Table.SelectRows(#"Día de la semana insertado", each [Día de la semana] = 6),
 #"Conservar las últimas filas" = Table.LastN(#"Filas filtradas", 1),
    CalendarStart = #"Conservar las últimas filas"{0}[Column1]+#duration(1,0,0,0)   
in
CalendarStart;

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

Fiscal5253CalendarCreator = [
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

Fiscal5253CalendarCreator.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { "Fiscal 53-53 Weeks Calendar Creator", Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = CalendarCreator.Icons,
    SourceTypeImage = CalendarCreator.Icons
];

CalendarCreator.Icons = [
    Icon16 = { Extension.Contents("CalendarCreator16.png"), Extension.Contents("CalendarCreator20.png"), Extension.Contents("CalendarCreator24.png"), Extension.Contents("CalendarCreator32.png") },
    Icon32 = { Extension.Contents("CalendarCreator32.png"), Extension.Contents("CalendarCreator40.png"), Extension.Contents("CalendarCreator48.png"), Extension.Contents("CalendarCreator64.png") }
];