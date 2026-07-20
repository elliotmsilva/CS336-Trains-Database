<%@ page language="java" contentType="text/html; charset=ISO-8859-1"
    pageEncoding="ISO-8859-1" import="com.cs336.dbmstrainsproject.*"%>
<%@ page import="java.io.*,java.util.*,java.sql.*"%>
<%@ page session="true" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
    <title>Train Database Management System Login</title>
</head>
<body>

<%
	//simple log in page for dbms train project
	//two sample logins made on mySQL:
		//jane doe (user: Admin) (pass: adminpass)
		
    String username = request.getParameter("username");
    String password = request.getParameter("password");
    String loginError = null;

    //only try to log in if the form was submitted
    if (username != null && password != null) {
        ApplicationDB db = new ApplicationDB();
        Connection conn = db.getConnection();

        boolean loggedIn = false;
        String role = null;

        try {
            //first check if username exists in Passenger table
            String checkUser = "SELECT * FROM Passenger WHERE username=?";
            PreparedStatement ps = conn.prepareStatement(checkUser);
            ps.setString(1, username);
            ResultSet rs = ps.executeQuery();

            //username exists in Passenger, now check password
            if (rs.next()) {
                if (rs.getString("password").equals(password)) {
                    loggedIn = true;
                    role = "customer";
                } else {
                    loginError = "Incorrect password. Please try again.";
                }
                
                
            //username not in passenger, check employee table
            } else {
                checkUser = "SELECT * FROM Employee WHERE username=?";
                ps = conn.prepareStatement(checkUser);
                ps.setString(1, username);
                rs = ps.executeQuery();

             	// username exists in Employee, now check password
                if (rs.next()) {
                    if (rs.getString("password").equals(password)) {
                        loggedIn = true;
                        role = rs.getString("role");
                    } else {
                        loginError = "Incorrect password. Please try again.";
                    }
                    
                    
                // username not found in either table
                } else {
                    loginError = "Username not found. Please check your username or register a new account.";
                }
            }

            if (loggedIn) {
                session.setAttribute("username", username);
                session.setAttribute("role", role);
            }

        } catch (Exception e) {
            out.println("<p>Error: " + e.getMessage() + "</p>");
        } finally {
            db.closeConnection(conn);
        }

        
        //login results:
        if (loggedIn) {
	    session.setAttribute("username", username);
	    session.setAttribute("role", role);
	
	    if (role.equals("manager")) {
	        response.sendRedirect("adminhome.jsp");
	    } else if (role.equals("rep")) {
	        response.sendRedirect("representativehome.jsp");
	    } else {
	        response.sendRedirect("customerhome.jsp");
	    }
	}

     
        
     //form was not submitted, show login screen   
    } else { %>
        <h2>Train Database Management System Login</h2>
    <% } %>

<% if (request.getParameter("username") == null ||
       (request.getParameter("username") != null &&
        session.getAttribute("username") == null)) { %>
        
        
    <% 
    //if theres an issue with the username or password, display error
    if (loginError != null) { %>
    <p style="color:red;"><%= loginError %></p>
<% } %>

    <form method="post" action="login.jsp">
        <table>
            <tr>
                <td>Enter your Username:</td>
                <td><input type="text" name="username"></td>
            </tr>
            <tr>
                <td>Enter your Password:</td>
                <td><input type="password" name="password"></td>
            </tr>
        </table>
        <input type="submit" value="Login">
    </form>
    <br>
    New customer? <a href="register.jsp">Register here</a>
<% } %>

</body>
</html>