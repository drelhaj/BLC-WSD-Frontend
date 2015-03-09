How to convert string to Base64 and vice versa using Powershell
For debugging purposes I needed a quick way to convert Base64 encoded string. My opinion is that  the easiest way to achieve is to use Powershell.

Here is the example how to convert string "Hello World" to Base64 using ToBase64String method:

PS C:\Temp>$b  = [System.Text.Encoding]::UTF8.GetBytes("Hello World")
PS C:\Temp>[System.Convert]::ToBase64String($b)
SGVsbG8gV29ybGQ=

And here is the example how to decode Base64 string using FromBase64String method:

PS C:\Temp>$b  = [System.Convert]::FromBase64String("SGVsbG8gV29ybGQ=")
PS C:\Temp>[System.Text.Encoding]::UTF8.GetString($b)
Hello World