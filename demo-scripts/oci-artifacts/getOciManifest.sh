#/bin/sh
# getManifest demo42.azurecr.io/samples/text:v1

set -e
export ARTIFACT=$1
export REGISTRY=$(echo $ARTIFACT | cut -d '/' -f 1)
export TAG=$(echo $ARTIFACT | cut -d ':' -f 2)
export REPOSITORY=$(echo $ARTIFACT | sed "s/$REGISTRY\///g" | sed "s/:$TAG//")
# export REPOSITORY=samples/text
echo "Retrieving OCI manifest for: https://"$REGISTRY/$REPOSITORY:$TAG

# echo https://$REGISTRY/$REPOSITORY:$TAG

# export REGISTRY=" --- you have to fill this out --- "
# export REPOSITORY=" --- you have to fill this out --- "
export AAD_ACCESS_TOKEN=$(az account get-access-token --query accessToken -o tsv)

export ACR_REFRESH_TOKEN=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
	-d "grant_type=access_token&service=$REGISTRY&access_token=$AAD_ACCESS_TOKEN" \
	https://$REGISTRY/oauth2/exchange \
	| jq '.refresh_token' \
	| sed -e 's/^"//' -e 's/"$//')
# echo "ACR Refresh Token obtained."

# Create the repo level scope
SCOPE="repository:$REPOSITORY:pull"

# to pull multiple repositories passing in multiple scope arguments. 
#&scope="repository:repo:pull,push"

export ACR_ACCESS_TOKEN=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
	-d "grant_type=refresh_token&service=$REGISTRY&scope=$SCOPE&refresh_token=$ACR_REFRESH_TOKEN" \
	https://$REGISTRY/oauth2/token \
	| jq '.access_token' \
	| sed -e 's/^"//' -e 's/"$//')
# echo "ACR Access Token obtained."

curl -s -H "Accept: application/vnd.oci.image.manifest.v1+json"   -H "Authorization: Bearer $ACR_ACCESS_TOKEN"  https://$REGISTRY/v2/$REPOSITORY/manifests/$TAG | jq
