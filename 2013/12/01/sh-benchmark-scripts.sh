## Parameter Expansion 1: "$PARAMETER"
i=$(zsh -c "echo {1..100000}"); time (: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";: "$i";)
## Parameter Expansion 2: $PARAMETER
i=$(zsh -c "echo {1..100000}"); time (: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;: $i;)
## Parameter Expansion 3: "${PARAMETER##*/}" (modifier)
path=/foo/bar; time (for i in {1..100000}; do : "${path##*/}";: "${path##*/}";: "${path##*/}";: "${path##*/}";: "${path##*/}";: "${path##*/}";: "${path##*/}";: "${path##*/}";: "${path##*/}";: "${path##*/}"; done)
## Array Parameter Expansion 1: "${ARRAY[1]}" (one element)
i=($(zsh -c "echo {1..1000000}")); time (for j in {1..10000}; do : "${i[1]}";: "${i[20]}";: "${i[300]}";: "${i[4000]}";: "${i[50000]}"; done)
## Array Parameter Expansion 2: "${ARRAY[@]}" (all elements)
i=($(zsh -c "echo {1..1000000}")); time (: "${i[@]}";: "${i[@]}";: "${i[@]}";: "${i[@]}";: "${i[@]}";)
## Arithmetic Evaluation 1: let EXPRESSION
j=0; time (for i in {1..1000000}; do let j++;let j++;let j++;let j++;let j++; done)
## Arithmetic Evaluation 2: ((EXPRESSION))
j=0; time (for i in {1..1000000}; do ((j++));((j++));((j++));((j++));((j++)); done)
## Arithmetic Expansion 1: $((EXPRESSION))
j=0; time (for i in {1..1000000}; do j=$((j+1));j=$((j+1));j=$((j+1));j=$((j+1));j=$((j+1)); done)
## Arithmetic Expansion 2: $(($PARAMETER+EXPRESSION))
j=0; time (for i in {1..1000000}; do j=$(($j+1));j=$(($j+1));j=$(($j+1));j=$(($j+1));j=$(($j+1)); done)
## Test 1: [[ EXPRESSION ]]
time (for i in {1..1000000}; do [[ -d . ]];[[ -d .. ]];[[ -d . ]];[[ -d .. ]];[[ -d . ]]; done)
## Test 2: [ EXPRESSION ]
time (for i in {1..1000000}; do [ -d . ];[ -d .. ];[ -d . ];[ -d .. ];[ -d . ]; done)
## Fork
set -- {1..10000}; time (for x; do : <(:);: <(:);: <(:);: <(:);: <(:); done)
## Fork & Exec
set -- {1..10000}; time (for x; do /bin/true;/bin/true;/bin/true;/bin/true; done)
## Iterate Parameters 1; for
set -- {1..1000000}; time (for x; do :; done)
## Iterate Parameters 2: while shift
set -- {1..100000}; time (while shift; do :; done 2>/dev/null)
## Iterate Parameters 3: while ((n++<$#))
set -- {1..100000}; n=1; time (while ((n++<$#)); do :; done)
