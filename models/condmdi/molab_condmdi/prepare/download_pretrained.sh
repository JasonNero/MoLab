mkdir -p save/
cd save/

echo "The pretrained models will be stored in the 'save' folder"

# condmdi (aka condmdi_random_joints)
if [ ! -d "condmdi_random_joints" ]; then
    echo "Downloading the condmdi model"
    gdown "1aP-z1JxSCTcUHhMqqdL2wbwQJUZWHT2j"
    echo "Extracting the condmdi model"
    mkdir -p condmdi_random_joints
    unzip condmdi_random_joints.zip -d condmdi_random_joints
    echo "Cleaning\n"
    rm condmdi_random_joints.zip
else
    echo "condmdi_random_joints already exists, skipping download"
fi

# condmdi_random_frames
if [ ! -d "condmdi_random_frames" ]; then
    echo "Downloading the condmdi_random_frames model"
    gdown "15mYPp2U0VamWfu1SnwCukUUHczY9RPIP"
    echo "Extracting the condmdi_random_frames model"
    mkdir -p condmdi_random_frames
    unzip condmdi_random_frames.zip -d condmdi_random_frames
    echo "Cleaning\n"
    rm condmdi_random_frames.zip
else
    echo "condmdi_random_frames already exists, skipping download"
fi

# condmdi_uncond (currently not used)
# if [ ! -d "condmdi_uncond" ]; then
#     echo "Downloading the condmdi_uncond model"
#     gdown "1B0PYpmCXXwV0a5mhkgea_J2pOwhYy-k5"
#     echo "Extracting the condmdi_uncond model"
#     mkdir -p condmdi_uncond
#     unzip condmdi_uncond.zip -d condmdi_uncond
#     echo "Cleaning\n"
#     rm condmdi_uncond.zip
# else
#     echo "condmdi_uncond already exists, skipping download"
# fi

echo "Downloading done!"
