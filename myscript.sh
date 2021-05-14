#!/bin/bash          

  # input parameters. -f = name of report
  while getopts f:b: flag
  do
      case "${flag}" in
           f) CONTENTFILE=${OPTARG};;
           b) Branch=${OPTARG};;
      esac
  done
  echo "input report name:"$CONTENTFILE
  echo "Feature branch name:"$Branch

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

    #set git settings
    git config --global user.name "Richard Down"
    git config --global user.email "richard.down@yahoo.co.uk"  
 
    #clean up local Git Repo
    rm -rf SAS-VA-Export-Testing
    
    #clone the remote repo
    git clone git@github.com:RichardDown/SAS-VA-Export-Testing.git


    #add new feature branch and switch
    git branch $Branch master
    git checkout $Branch
echo "branched and moved over"    
    #add the output transfer package file
    git add transferpackage.json
echo "added file"
    #commit the new file and name it with the report name
    git commit -m "VA Report: $CONTENTFILE"
echo "commited change"
    # Push loca repo to remote repo
    git push git@github.com:RichardDown/SAS-VA-Export-Testing.git $Branch
echo "pushed to branch"

else
   echo "report not found"

 fi

