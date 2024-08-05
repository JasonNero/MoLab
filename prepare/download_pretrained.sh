mkdir -p save/
cd save/

echo "The pretrained models will be stored in the 'save' folder\n"

# condmdi (aka condmdi_random_joints)
echo "Downloading the condmdi model"
gdown "1aP-z1JxSCTcUHhMqqdL2wbwQJUZWHT2j"
echo "Extracting the condmdi model"
unzip condmdi_random_joints.zip
echo "Cleaning\n"
rm condmdi_random_joints.zip

# condmdi_random_frames
echo "Downloading the condmdi_random_frames model"
gdown "15mYPp2U0VamWfu1SnwCukUUHczY9RPIP"
echo "Extracting the condmdi_random_frames model"
unzip condmdi_random_frames.zip
echo "Cleaning\n"
rm condmdi_random_frames.zip

# condmdi_uncond
echo "Downloading the condmdi_uncond model"
gdown "1B0PYpmCXXwV0a5mhkgea_J2pOwhYy-k5"
echo "Extracting the condmdi_uncond model"
unzip condmdi_uncond.zip
echo "Cleaning\n"
rm condmdi_uncond.zip

echo "Downloading done!"
