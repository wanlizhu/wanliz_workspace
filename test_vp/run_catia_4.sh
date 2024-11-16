if [[ ! -f ./viewperf/bin/viewperf ]]; then
    pushd ~/viewperf2020 || exit 1
fi

cat <<EOF > viewsets/catia/config/catia_4.xml
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE SPECGWPG>
<SPECGWPG Name="SPECviewperf" Version="v2.0" AppName="Dassault Syst&#xE8;mes CATIA V5 and 3DExperience" Results="results.xml" Log="log.txt">
    <Viewset Name="catia-06" Library="catia" Directory="catia" Threads="-1" Options="" Version="2.0">
        <Window Resolution="3840x2160" Height="2120" Width="3800" X="10" Y="20" Suffix="-4k"/>
        <Window Resolution="1920x1080" Height="1060" Width="1900" X="10" Y="20"/>
        <Test Name="catiav5test4" Index="1" Weight="14.28" Seconds="15.0" Description='Catia V5 ICD car - multiple views, shaded with edges'>
            <Grab Name="CATIA_V5_ICDcarMulti.png" Frames="1" X="0" Y="0"/>
        </Test>
    </Viewset>
</SPECGWPG>
EOF

mkdir -p results/catia-06/ &&
./viewperf/bin/viewperf viewsets/catia/config/catia_4.xml -resolution 1920x1080 &&
grep '<Test Index=' results/catia-06/results.xml | awk -F '"' '{print $10}' 

