<#
Added a mail message direct from provision in Junk filters the autoprovision message.
Please see the file structure and make sure it is in place.
users to be provisioned are located in the CSV.

#>
$creds = get-credential
Connect-MsolService -Credential $creds
$sendemail = Import-Csv C:\scripts\O365Createdusers.csv
$cc = "inputCChere@changethis.com"
$url = "https://portal.office.com"


Import-Csv -Path C:\scripts\AddMSOLUsers.csv | foreach {New-MsolUser -DisplayName $_.DisplayName -FirstName $_.FirstName -LastName $_.LastName -UserPrincipalName $_.UserPrincipalName -UsageLocation $_.UsageLocation -LicenseAssignment $_.AccountSkuId } | Export-Csv -Path C:\scripts\O365Createdusers.csv -NoTypeInformation
$sendemail = Import-Csv C:\scripts\O365Createdusers.csv
foreach ($user in $sendemail){

                                            $username = $user.UserPrincipalName
                                            $password = $user.password

                                            Send-MailMessage -To "$username","$cc" -From $cc -Subject "SharePoint Online account" -Body "Welcome to $url. Your username is $username and password is $password" -SmtpServer smtp.youdomain.com
                                            }

Clear-Variable sendemail, creds 
