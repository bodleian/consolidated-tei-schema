module namespace bod="http://www.bodleian.ox.ac.uk/bdlss";
import module namespace functx = "http://www.functx.com" at "functx.xquery";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~
 : --------------------------------
 : Function Library for TEI catalogues
 : --------------------------------

 : This library is for useful generic functions (date handling, language code lookups, etc)
 : and functions specific to building the Solr files for specific indexes, but likely to be 
 : shared across multiple TEI catalogues  
 :
:)


declare variable $bod:disablelogging as xs:boolean external := false();



(:~
 : --------------------------------
 : Generic helper functions
 : --------------------------------
:)


declare function bod:logging($level, $msg, $values)
{
    if (not($bod:disablelogging)) then
        (: Trick XQuery into doing trace() to output message to STDERR but not insert it into the XML :)
        substring(trace('', concat(upper-case($level), '	', $msg, '	', string-join($values, '	'), '	')), 0, 0)
    else ()
};


declare function bod:ordinal($num as xs:integer) as xs:string
{
    switch($num)
        case 1 return "st"
        case 2 return "nd"
        case 3 return "rd"
        default return "th"
};


declare function bod:formatCentury($centuryNum as xs:integer) as xs:string
{
    (: Converts century in number form (negative integers for BCE, positive integers for CE) into human-readable form :)
    if ($centuryNum gt 0) then
        concat($centuryNum, bod:ordinal($centuryNum), ' Century')
    else
        concat(abs($centuryNum), bod:ordinal(abs($centuryNum)), ' Century BCE')
};


declare function bod:findCenturies($earliestYear, $latestYear) as xs:string*
{
    (: Converts a year range (or single year) into a sequence of century names :)

    (: Zero below stands for null, as there is no Year 0 :)
    let $ey as xs:double := number(functx:if-empty($earliestYear, 0))
    let $ly as xs:double := number(functx:if-empty($latestYear, 0))
    
    let $earliestIsTurnOfCentury as xs:boolean := ends-with($earliestYear, '00')
    let $latestIsTurnOfCentury as xs:boolean := ends-with($latestYear, '00')
    
    (: Convert years to centuries. Special cases required for turn-of-the-century years, e.g. 1500 AD is treated 
       as 16th century if at the start of a range, or the only known year, but as 15th if at the end of a range; 
       while 200 BC is treated as 3rd century BCE if at the end of a range but as 2nd BCE at the start. :)
    let $earliestCentury as xs:integer := xs:integer(
        if ($ey gt 0 and $earliestIsTurnOfCentury) then 
            ($ey div 100) + 1
        else if ($ey lt 0) then
            floor($ey div 100)
        else 
            ceiling($ey div 100)
        )      
    let $latestCentury as xs:integer := xs:integer(
        if ($ly lt 0 and $latestIsTurnOfCentury) then 
            ($ly div 100) - 1
        else if ($ly lt 0) then
            floor($ly div 100)
        else 
            ceiling($ly div 100)
        )

    return    
        if ($ey gt $ly and $ly ne 0) then
            bod:logging('info', 'Date range not valid so will not be added to century filter', concat($earliestYear, '-', $latestYear))
            
        else if ($earliestCentury ne 0 and $latestCentury ne 0) then
            (: A date range, something like "After 1400 and before 1650", so fill in all the possible centuries between :)
            for $century in (-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)
                return
                    if ($century ge $earliestCentury and $century le $latestCentury) then
                        bod:formatCentury($century)
                    else
                        ()
         else
            (: Only a single date, either a precise year or an open-ended range like "Before 1500" or "After 1066", so just output the known century :)
            bod:formatCentury(($earliestCentury, $latestCentury)[. ne 0])
};


declare function bod:languageCodeLookup($lang as xs:string) as xs:string
{
    switch($lang)
        case "English" return "English" 
        case "French" return "French"
        case "Hebrew" return "Hebrew" 
        case "an" return "Spanish"
        case "ang" return "English"
        case "ar" return "Arabic"
        case "ara" return "Arabic"
        case "ara-Latn-x-lc" return "Arabic"
        case "ara-Latn-x-lx" return "Arabic"
        case "br" return "French"
        case "ca" return "Catalan"
        case "cop" return "Coptic"
        case "cs" return "Czech"
        case "cu" return "Church Slavonic"
        case "cy" return "Welsh"
        case "de" return "German"
        case "dlm" return "Dalmatian"
        case "egy-Egyd" return "Egyptian in Demotic script"
        case "egy-Egyh" return "Egyptian in Hieratic script"
        case "el" return "Greek"
        case "en" return "English"
        case "eng" return "English"
        case "eng-Latn-x-lc" return "English"
        case "es" return "Spanish"
        case "fr" return "French"    
        case "fre" return "French"
        case "fy" return "Frisian"
        case "ga" return "Irish"
        case "gd" return "Gaelic"
        case "ger" return "German"
        case "grc" return "Greek"
        case "he" return "Hebrew"
        case "hr" return "Croatian"
        case "hu" return "Hungarian"
        case "is" return "Icelandic"
        case "it" return "Italian"
        case "ita" return "Italian"
        case "kw" return "Cornish"
        case "la" return "Latin"
        case "lat" return "Latin"
        case "nah" return "Nahuatl"
        case "nl" return "Dutch/Flemish"
        case "pro" return "French"
        case "pt" return "Portugese"
        case "ru" return "Russian"
        case "rus" return "Russian"
        case "sco" return "Scots"
        case "spa" return "Spanish"
        case "syc" return "Syriac"
        case "zxx" return "No Linguistic Content"
        default return $lang
};

declare function bod:personRoleLookup($role as xs:string) as xs:string
{
    (: Most of the roles just need to be capitalized. These are the exceptions.
       Probably common across all catalogues, but if not can be locally overridden :)
    switch($role)
        case "formerOwner" return "Owner or signer"
        case "signer" return "Owner or signer"
        case "commissioner" return "Commissioner, dedicatee, or patron"
        case "dedicatee" return "Commissioner, dedicatee, or patron"
        case "patron" return "Commissioner, dedicatee, or patron"
        default return functx:capitalize-first($role)
};

declare function bod:orgRoleLookup($role as xs:string) as xs:string
{
    (: For the moment, using the same roles as persons. But could add organization-specific ones here. :)
    let $normalizedRole := bod:personRoleLookup($role)
    return $normalizedRole
};


declare function bod:alphabetize($string as xs:string) as xs:string
{
    (: TODO: Strip off stopwords first (e.g. don't return 'T' for 'The Annals of Ulster') :)
    let $firstLetter := functx:capitalize-first(substring(replace($string, '[^\p{L}|\p{N}]+', ''), 1, 1))
    return $firstLetter
};


declare function bod:pathFromCollections($fullpath as xs:string) as xs:string
{
    let $relativepath as xs:string := substring-after($fullpath, 'collections/')
    return $relativepath
};








(:~
 : --------------------------------
 : TEI-to-Solr field mapping functions
 : --------------------------------
:)

declare function bod:one2one_TESTING($teinode as element()*, $solrfield as xs:string)
{
    (: One TEI element maps to a single Solr field :)
    let $value as xs:string := normalize-space(string-join($teinode[1]//text(), ' '))
    return if (count($teinode) lt 2) then
        if (string-length($value) gt 0) then
            <field name="{ $solrfield }">{ $value }</field>
        else
            ()
    else
        bod:logging('error', concat(count($teinode), ' elements found when only one expected for ', $solrfield), bod:pathFromCollections(base-uri($teinode[1])))
};



declare function bod:one2one($teinode as element()?, $solrfield as xs:string)
{
    (: One TEI element maps to a single Solr field :)
    let $value as xs:string := normalize-space(string-join($teinode//text(), ' '))
    return if (string-length($value) gt 0) then
        <field name="{ $solrfield }">{ $value }</field>
    else
        ()
};


declare function bod:many2one($teinodes as element()*, $solrfield as xs:string)
{
    (: Concatenate a sequence of TEI elements, into a single Solr field :)
    let $values as xs:string* := $teinodes/string-join(.//text(), ' ')
    return if (not(empty($values))) then
        <field name="{ $solrfield }">{ normalize-space(string-join(distinct-values($values), ' ')) }</field>  
    else
        ()
};


declare function bod:many2many($teinodes as element()*, $solrfield as xs:string)
{
    (: Generate multiple Solr fields, one for each distinct value from a sequence of TEI elements :)
    let $values as xs:string* := for $n in $teinodes return normalize-space(string-join($n//text()))
    for $v in distinct-values($values)
        return
            if (string-length($v) > 0) then
                <field name="{ $solrfield }">{ $v }</field>
            else ()
};


declare function bod:trueIfExists($teinode as element()*, $solrfield as xs:string)
{
    (: Return true/false Solr field depending on presence of a TEI field :)
    let $exists as xs:boolean := exists($teinode)
    return if ($exists = true()) then
        <field name="{ $solrfield }">true</field>
    else
        <field name="{ $solrfield }">false</field>
};


declare function bod:dateEarliest($teinodes as element()*, $solrfield as xs:string)
{
    (: Find the earliest date of all TEI date/origDate fields passed to it :)
    let $dates := $teinodes[string(number(@notBefore)) != 'NaN']/@notBefore
    return if (empty($dates)) then
        ()
    else
        <field name="{ $solrfield }">{ min($dates) }</field>
};


declare function bod:dateLatest($teinodes as element()*, $solrfield as xs:string)
{
    (: Find the latest date of all TEI date/origDate fields passed to it :)
    let $dates := $teinodes[string(number(@notAfter)) != 'NaN']/@notAfter
    return if (empty($dates)) then
        ()
    else
        <field name="{ $solrfield }">{ max($dates) }</field>
};


declare function bod:centuries($teinodes as element()*, $solrfield as xs:string)
{
    (: Convert TEI date files into one Solr field for each century covered by 
       the year or year-range specified in @when/@notAfter/@NotBefore attributes :)
    let $centuries := (
        for $date in $teinodes
            return
            if ($date[@when]) then 
                bod:findCenturies($date/@when/data(), '')
            else if ($date[@notBefore] or $date[@notAfter]) then
                bod:findCenturies($date/@notBefore/data(), $date/@notAfter/data())
            else
                ()
        )
    for $century in distinct-values($centuries)
        order by $century
        return if (string-length($century) gt 0) then <field name="{ $solrfield }">{ $century }</field> else ()
};


declare function bod:materials($teinodes as element()*, $solrfield as xs:string)
{
    for $item in distinct-values($teinodes/string(@material))
        let $material := (
            switch ($item)
                case "perg" return "Parchment"
                case "chart" return "Paper"
                case "papyrus" return "Papyrus"
                case "mixed" return "Mixed"
                case "unknown" return "Unknown"
                default return "Other")
        return <field name="{ $solrfield }">{ $material }</field>
};


declare function bod:languages($teinodes as element()*, $solrfield as xs:string)
{
    let $langCodes := for $attr in $teinodes/@* return if (name($attr) = 'mainLang' or name($attr) = 'otherLangs') then tokenize($attr, ' ') else ()
    for $code in distinct-values($langCodes)
        return <field name="{ $solrfield }">{ normalize-space(bod:languageCodeLookup($code)) }</field>
};



