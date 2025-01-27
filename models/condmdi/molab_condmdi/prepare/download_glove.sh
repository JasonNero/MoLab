echo -e "Downloading glove (in use by the evaluators, not by GMD itself)"

# condmdi (aka condmdi_random_joints)
if [ ! -d "glove" ]; then
    gdown --fuzzy https://drive.google.com/file/d/1cmXKUT31pqd7_XpJAiWEo1K81TMYHA5n/view?usp=sharing
    echo "Extracting glove model"
    unzip glove.zip
    echo "Cleaning\n"
    rm glove.zip
else
    echo "glove already exists, skipping download"
fi

echo -e "Downloading done!"
