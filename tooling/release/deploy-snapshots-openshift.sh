#!/usr/bin/env bash

# Example :
# Openshift Online (Token)  --> ./deploy-snapshots-openshift.sh -a https://api.engint.openshift.com -t xxxxxxxxxxxx
# CI Server (User/password) --> ./deploy-snapshots-openshift.sh -a https://172.16.50.40:8443 -u admin -p admin
# Local vagrant             --> ./deploy-snapshots-openshift.sh \
#           -a 172.28.128.4:8443 -u admin -p admin \
#           -v 1.0.0-SNAPSHOT \
#           -b http://backend-generator-obsidian-snapshot.172.28.128.4.xip.io/ \
#           -c 'http://nexus-infra.172.28.128.4.xip.io/service/local/artifact/maven/redirect?r=public\&g=org.obsidiantoaster\&a=archetypes-catalog\&v=1.0.0-SNAPSHOT\&e=xml&c=archetype-catalog' \
#           -n http://nexus-infra.172.28.128.4.xip.io
#
# Using JBoss Nexus Server
# 1) Local deployment
# ./deploy-snapshots-openshift.sh -a 172.28.128.4:8443 -u admin -p admin \
#                                 -v 1.0.0-SNAPSHOT \
#                                 -b http://backend-generator-obsidian-snapshot.172.28.128.4.xip.io/ \
#                                 -c 'http://repository.jboss.org/nexus/service/local/artifact/maven/redirect?r=snapshots\&g=org.obsidiantoaster\&a=archetypes-catalog\&v=1.0.0-SNAPSHOT\&e=xml\&c=archetype-catalog' \
#                                 -n http://repository.jboss.org/nexus
#
# 2) Using OpenShift Online
#./deploy-snapshots-openshift.sh -a https://api.engint.openshift.com -t xxxxxxxxx \
#                                -v 1.0.0-SNAPSHOT \
#                                -b http://backend-generator-obsidian-snapshot.e8ca.engint.openshiftapps.com/ \
#                                -c 'http://repository.jboss.org/nexus/service/local/artifact/maven/redirect?r=snapshots\&g=org.obsidiantoaster\&a=archetypes-catalog\&v=1.0.0-SNAPSHOT\&e=xml&\c=archetype-catalog' \
#                                -n http://repository.jboss.org/nexus
#

while getopts a:t:u:p:v:b:c:n: option
do
        case "${option}"
        in
                a) api=${OPTARG};;
                t) token=${OPTARG};;
                u) user=${OPTARG};;
                p) password=${OPTARG};;
                v) version=${OPTARG};;
                b) backendurl=${OPTARG};;
                c) archetypecatalog=${OPTARG};;
                n) mavenserver=${OPTARG};;

        esac
done

current=$PWD

echo "============================="
echo "Log on to the OpenShift server"
echo "============================="
if [ "$token" != "" ]; then
   oc login $api --token=$token
else
   echo "oc login $api -u $user -p $password"
   oc login $api -u $user -p $password
fi

REL=$version
githuborg="obsidian-toaster"
mavenmirrorurl=$mavenserver/content/repositories/snapshots

echo "============================="
echo "Version for the front : $REL"
echo "Backend : $backendurl"
echo "Github Org : $githuborg"
echo "Catalog URL : $archetypecatalog"
echo "Maven Server : $mavenserver"
echo "Maven Mirror URL : $mavenmirrorurl"
echo "============================="

# Change version
sed -e "s/VERSION/$REL/g" -e "s/ORG\//$githuborg\//g" -e "s|MAVENSERVER|$mavenserver|g" -e "s|MAVENMIRRORURL|$mavenmirrorurl|g"  -e "s|ARCHETYPECATALOG|$archetypecatalog|" ./templates/backend-deploy.yml > ./templates/backend-$REL.yml
sed -e "s/VERSION/$REL/g" -e "s|GENERATOR_URL|$backendurl|g" -e "s/ORG\//$githuborg\//g" ./templates/front-deploy.yml > ./templates/front-$REL.yml

#
# Remove first 6 chars otherwise OpenShift will complaints --> metadata.name: must match the regex [a-z0-9]([-a-z0-9]*[a-z0-9])? (e.g. 'my-name' or '123-abc')
#
suffix=${REL:6}
suffix_lower=$(echo $suffix | tr '[:upper:]' '[:lower:]')
echo "Project to be created : obsidian-$suffix_lower"


# Create project
echo "============================="
echo "Create Openshift namespace : obsidian-$suffix_lower"
echo "============================="

oc new-project obsidian-$suffix_lower
sleep 5

# Deploy the backend
echo "============================="
echo "Deploy the backend template"
echo "============================="
oc create -f ./templates/backend-$REL.yml
oc process backend-generator-s2i | oc create -f -
oc start-build backend-generator-s2i

# Deploy the Front
echo "============================="
echo "Deploy the frontend ..."
echo "============================="
oc create -f templates/front-$REL.yml
oc process front-generator-s2i | oc create -f -
oc start-build front-generator-s2i

