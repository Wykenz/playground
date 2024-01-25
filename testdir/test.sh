#!/bin/bash

color_to_find="orange"
yaml_file="your_file.yaml"

# Convert YAML to JSON and search for the key(s) with the specified color
keys=$(yq eval ". as \$items | paths | select(getpath(\$items) == \"$color_to_find\") | join(\".\")" "$yaml_file" | jq -r '.[]')

# Print the result
echo "Keys with color containing $color_to_find: $keys"
