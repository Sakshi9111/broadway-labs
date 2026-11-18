########################
#  Install Java        #
########################

sudo apt update
sudo apt install default-jdk -y

#######################
# Verify Installation #
#######################
java --version
javac -version

######################
#  Run application  ##
######################

javac HelloStudents.java
java HelloStudents


###########################
mvn clean package
###########################



