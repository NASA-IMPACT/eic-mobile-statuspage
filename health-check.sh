# In the original repository we'll just print the result of status checks,
# without committing. This avoids generating several commits that would make
# later upstream merges messy for anyone who forked us.
commit=true
origin=$(git remote get-url origin)
if [[ $origin == *statsig-io/statuspage* ]]
then
  commit=false
fi

KEYSARRAY=()
URLSARRAY=()

urlsConfig="./urls.cfg"
echo "Reading $urlsConfig"

while IFS='=' read -r key url
do
  # Trim any leading/trailing whitespaces
  key=$(echo "$key" | xargs)
  url=$(echo "$url" | xargs)
  
  # Skip empty lines or lines without a valid URL
  if [[ -n "$key" && -n "$url" ]]; then
    echo "Key: $key, URL: $url"
    KEYSARRAY+=("$key")
    URLSARRAY+=("$url")
  fi
done < "$urlsConfig"


echo "***********************"
echo "Starting health checks with ${#KEYSARRAY[@]} configs:"

mkdir -p logs

for (( index=0; index < ${#KEYSARRAY[@]}; index++))
do
  key="${KEYSARRAY[index]}"
  url="${URLSARRAY[index]}"
  echo "===> $key=$url"

  for i in 1 2 3 4; 
  do
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null $url)
    echo $response
    if [[ "$key" == "gis" ]]; then
      title=$(curl -H "referer: $REFERER" -H "X-Esri-Authorization: Bearer $GIS_TOKEN" -s $url)
      if [[ "$title" =~ [eE]rror ]]; then
        response=500
      fi
    fi
    if [ "$response" -eq 200 ] || [ "$response" -eq 202 ] || [ "$response" -eq 301 ] || [ "$response" -eq 302 ] || [ "$response" -eq 307 ]; then
      result="success"
    else
      result="failed"
    fi
    if [ "$result" = "success" ]; then
      break
    fi
    sleep 5
  done
  dateTime=$(date +'%Y-%m-%d %H:%M')
  if [[ $commit == true ]]
  then
    echo $dateTime, $result >> "logs/${key}_report.log"
    # By default we keep 2000 last log entries.  Feel free to modify this to meet your needs.
    echo "$(tail -2000 logs/${key}_report.log)" > "logs/${key}_report.log"
  else
    echo "    $dateTime, $result"
  fi
done


