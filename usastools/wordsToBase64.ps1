$words = Import-Csv E:\workspace\scripts\wordsUSAS.csv -header Word, base64
ForEach ($word in $words){

$b  = [System.Text.Encoding]::UTF8.GetBytes($word.Word)
$word.base64 = [System.Convert]::ToBase64String($b)
$url = "http://localhost:8080/form?word="+$word.base64+"&lang=en&timeout=30&source=amt" 
Write-Host $url
}
