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
		//jane doe (user: jdoe) (pass: admin123)
		//john smith (user: jsmith) (pass: password123)
	
    String username = request.getParameter("username");
    String password = request.getParameter("password");

    //only try to log in if the form was submitted
    if (username != null && password != null) {
        ApplicationDB db = new ApplicationDB();
        Connection conn = db.getConnection();

        boolean loggedIn = false;
        String role = null;

        try {
            //check passenger table from mysql database
            String sql = "SELECT * FROM passenger WHERE username=? AND password=?";
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setString(1, username);
            ps.setString(2, password);
            ResultSet rs = ps.executeQuery();

            if (rs.next()) {
                loggedIn = true;
                role = "passenger";
                
            } else {
                //check employee table
                sql = "SELECT * FROM employee WHERE username=? AND password=?";
                ps = conn.prepareStatement(sql);
                ps.setString(1, username);
                ps.setString(2, password);
                rs = ps.executeQuery();
                if (rs.next()) {
                    loggedIn = true;
                    role = rs.getString("role");
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
        if (loggedIn) { %>
            <h3>Welcome, <%= username %>!</h3>
            <p>You are logged in as: <%= role %></p>
            <a href="logout.jsp">Logout</a>
            
        <% } else { %>
            <h3>Invalid username or password.</h3>
        <% }

     
        
     //form was not submitted, show login screen   
    } else { %>
        <h2>Train Database Management System Login</h2>
    <% } %>

<% if (request.getParameter("username") == null ||
       (request.getParameter("username") != null &&
        session.getAttribute("username") == null)) { %>
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
<% } %>

</body>
</html>