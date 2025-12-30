#!/bin/bash

# grab the purest color definition file
input="$HOME/.cache/wal/colors"
i=0
content="* {\n"
while IFS= read -r line
do
    # generate the color list for my style config
    if [ $i -eq 0 ]; then
        content="${content}  background: ${line};\n"
    fi
    content="${content}  color$i: ${line};\n"
    ((i++))
done < "$input"
content="${content}}\n"

printf "$content"
printf "$content" > "pywal-theme.rasi"
