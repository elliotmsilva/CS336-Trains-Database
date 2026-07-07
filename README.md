## Setup Instructions

### Database Setup
1. Open MySQL Workbench
2. Run the provided `cs336project.sql` file to create the database and tables
3. Default credentials are in the sql file
       **CHANGES TO DATABASE WILL REQUIRE REUPLOAD OF FILE

### Eclipse Setup
1. Clone this repo into your Eclipse workspace
2. In Eclipse: File → Import → Existing Projects into Workspace
3. Open ApplicationDB.java and change the password to your local MySQL password
        **DO NOT PUSH ANY CHANGES TO THIS FILE
        **THE LOGIN IS FOR YOUR DATABASE ACCESS ONLY, IT IS DIFFERENT FOR EVERYONE
   
5. Right-click project → Run As → Run on Server (Tomcat 11)
6. Navigate to localhost:8080/CS336Project/login.jsp

### Test Credentials
- Customer: username=jsmith / password=password123
- Manager: username=jdoe / password=admin123

## Important
After cloning, run this command in your Eclipse terminal to prevent accidentally pushing your local DB password:
git update-index --assume-unchanged src/main/java/com/cs336/dbmstrainsproject/ApplicationDB.java
Then open ApplicationDB.java and change the password to your local MySQL password.
