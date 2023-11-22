#!/bin/bash
#
# requirements:
#   aws CLI installed
#     Also must have correct aws profile/api keys installed.
#   jq installed
#
# ###########################################################################

# ###########################################################################
# Globals
# ###########################################################################
PATH=${PATH} # extend or remove path elements here based on your business requirements

# executables 
AWS=/usr/local/bin/aws # set full path if desired (or use the PATH ENV above)
JQ=/usr/local/bin/jq   # same with jq
GREP=/usr/bin/grep
CUT=/usr/bin/cut
ECHO=/bin/echo


DEFAULT_AWS_PROFILE='gather-client'
AWS_HOSTED_ZONE_FILE=hosted_zone_list


# ###########################################################################
# functions
# ###########################################################################
# #################################
# printUsage
# #################################
printUsage () {
   cat <<  "HERE"
   Usage: $0 -d <DOMAIN>  [-p <AWS_PROFILE>] | [-h] | [-?]

   -d <DOMAIN>         : Domain to search for
   -p <AWS_PROFILE>    : AWS PROFILE to use
   -h                  : Display Usage
   -?                  : Display Usage
   -v <LEVEL>          : VERBOSE set to LEVEL
HERE

}

# #################################
# rebuildAWSZoneMap
# #################################
rebuildAWSZoneMap () {
   # ${AWS} --profile ${AWS_PROFILE} route53 list-hosted-zones-by-name | ${JQ} -r '.HostedZones| .[] | {Name, Id} | join(" ")' | tee ${AWS_HOSTED_ZONE_FILE}
   ${AWS} --profile ${AWS_PROFILE} route53 list-hosted-zones-by-name | ${JQ} -r '.HostedZones| .[] | {Name, Id} | join(" ")' >  ${AWS_HOSTED_ZONE_FILE}
}

# #################################
# getZoneId
# #################################
getZoneId () {
   echo "Getting Zone ID"
   ZONE_MAP=`${GREP} "${DOMAIN}. /hostedzone/" ${AWS_HOSTED_ZONE_FILE}`
   if [ "${ZONE_MAP}" == "" ] ; then
      rebuildZWSZoneMap
   fi
   ZONE_MAP=`${GREP} "${DOMAIN}. /hostedzone/" ${AWS_HOSTED_ZONE_FILE}`
   eval "$1=`${ECHO} ${ZONE_MAP} | ${CUT} -d\" \" -f 2 `"
   if [ -z $1 ]; then
      echo "Rebuilding AWS Zone Map file"
      rebuildZWSZoneMap
      if [ ! -z ${ZONE_MAP} ] ; then
         eval "$1=`${ECHO} ${ZONE_MAP} | ${CUT} -d\" \" -f 2 `"
      fi 
      if [ -z $1 ]; then 
         echo "${DOMAIN} is NOT found in this AWS account."
         exit 3
      fi
   fi
}

# #################################
# getRecordSets
# #################################
getRecordSets () {
   AWS_ZONE_FILE=AWS_ZONE.${DOMAIN}
   ${AWS} --profile ${AWS_PROFILE} route53 list-resource-record-sets --hosted-zone-id ${ZONE_ID} > ${AWS_ZONE_FILE}
   ${CAT} ${AWS_ZONE_FILE} | jq -jr '.ResourceRecordSets[] | "\(.Name) \t\(.TTL? // 60) \t\(.Type) \t\(.ResourceRecords[]?.Value // .AliasTarget?.DNSName)\n"'
}

# ###########################################################################
# Main
# ###########################################################################
USAGE=0

if [ "$1" == "?" ] ; then
   USAGE=1;
fi

while getopts ?hd:s:k:p: flag
do 
   case "${flag}" in
      d) DOMAIN=${OPTARG};;
      p) AWS_PROFILE=${OPTARG};;
      v) VERBOSE=${OPTARG};;
      h) USAGE=1;;
      ?) USAGE=1;;
   esac
done

if [ ${USAGE} -eq 1 ]; then
   printUsage
   exit 1
fi

if [ -z "${AWS_PROFILE}" ] ; then
   AWS_PROFILE=${DEFAULT_AWS_PROFILE}
fi

if [ "${DOMAIN}" == "" ] ; then
   echo "No DOMAIN found."
   printUsage
   exit 2
fi
ZONE_ID=''
getZoneId ZONE_ID
