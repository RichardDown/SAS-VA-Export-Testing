#!/bin/bash          

  # input parameters. -f = name of report
  while getopts p:f: flag
  do
      case "${flag}" in
           f) CONTENTFILE=${OPTARG};;
      esac
  done
  echo "input report name:"$CONTENTFILE":"

  #user for CLI access
  ID="sasdemo"
  #password is gpg encrypted using private key in home directory
  MYPASSWORD=$(gpg --decrypt passwordfile.txt.gpg)
 
  #cet needed for CLI access
  export SSL_CERT_FILE=/opt/sas/viya/config/etc/SASSecurityCertificateFramework/cacerts/trustedcerts.pem

  #path for CLI commands
  clidir=/opt/sas/viya/home/bin

  #set profile settings
  $clidir/sas-admin profile set-endpoint "https://sasserver.demo.sas.com"
  $clidir/sas-admin profile toggle-color off
  $clidir/sas-admin profile set-output text

  #create profile for CLI access
  $clidir/sas-admin --profile $ID profile init --set-endpoint "https://sasserver.demo.sas.com"
  
  #login to profile
  $clidir/sas-admin auth login --user $ID --password $MYPASSWORD
 
  #find the report information via the CLI
  $clidir/sas-admin reports list --name "$CONTENTFILE" | grep "$CONTENTFILE" &> /dev/null
  #if report is found then process else bypass and end
  if [ $? == 0 ]; then
    echo "Report: "$CONTENTFILE" Found" 
    #REPORTID is the URI of the report that we need to export the report
    REPORTID=$($clidir/sas-admin reports list --name "$CONTENTFILE")
    REPORTID=${REPORTID##* }
    REPORTID='/reports/reports/'$REPORTID

    #export the report to a transfer file
    EXPORTEDFILE=$($clidir/sas-admin transfer export --resource-uri "$REPORTID")

    #find the transport file name
    TOTALWORDS=$(wc -w <<< $EXPORTEDFILE)
    TOTALWORDS=$(($TOTALWORDS-2))
    EXPORTID=$(echo $EXPORTEDFILE | cut -d " " -f $TOTALWORDS)

    #set the JSON filename to put the exported report into
    JSONFILENAME="transferpackage.json"

    #download the transport file as a JSON file ready to promote to another environment
    $clidir/sas-admin transfer download --id $EXPORTID  --file $JSONFILENAME

    echo "created JSON file: "$JSONFILENAME" based on export package: "$EXPORTID

    #connect to git project
    git config --global user.name "Richard Down"
    git config --global user.email "richard.down@sas.com"  
 
    git clone https://gitlab.sas.com/sukrdo/sukrdo-devops-project.git
    cd sukrdo-devops-project
    git add README.md
    git commit -m "add README"
    git push -u origin master

else
   echo "report not found"

 fi

