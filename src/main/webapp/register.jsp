<%@ page language="java" contentType="text/html; charset=ISO-8859-1"
    pageEncoding="ISO-8859-1" import="com.cs336.dbmstrainsproject.*"%>
<%@ page import="java.io.*,java.util.*,java.sql.*"%>
<%@ page session="true" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
    <title>Register</title>
</head>
<body>

<%
	//get parameters to insert a customer into the sql database
    String firstname = request.getParameter("firstname");
    String lastname = request.getParameter("lastname");
    String email = request.getParameter("email");
    String username = request.getParameter("username");
    String password = request.getParameter("password");

    //only try to register if form was fully filled out
    if (firstname != null && lastname != null && email != null
            && username != null && password != null) {

        ApplicationDB db = new ApplicationDB();
        Connection conn = db.getConnection();
        boolean registered = false;
        String errorMsg = null;

        try {
            //check if username already exists in dbms
            String check = "SELECT * FROM Passenger WHERE username=?";
            PreparedStatement ps = conn.prepareStatement(check);
            ps.setString(1, username);
            ResultSet rs = ps.executeQuery();

            //in use, make repick username
            if (rs.next()) {
                errorMsg = "Username already taken, please choose another.";
            
            //not in use, insert new customer into dbms
            } else {
                String sql = "INSERT INTO Passenger (username, password, first_name, last_name, email) VALUES (?, ?, ?, ?, ?)";
                ps = conn.prepareStatement(sql);
                ps.setString(1, username);
                ps.setString(2, password);
                ps.setString(3, firstname);
                ps.setString(4, lastname);
                ps.setString(5, email);
                ps.executeUpdate();
                registered = true;
            }

        } catch (Exception e) {
            errorMsg = "Error: " + e.getMessage();
        } finally {
            db.closeConnection(conn);
        }

        
        //if successfully registered, redirect to the customer landing
        if (registered) {
            session.setAttribute("username", username);
            session.setAttribute("role", "customer");
            response.sendRedirect("customerhome.jsp");
            return;
        } else { %>
            <p style="color:red;"><%= errorMsg %></p>
        <% }
        
        
    //show form:
    } else { %>
        <h2>Enter the following information to create a new account:</h2>
    <% } %>

    <form method="post" action="register.jsp">
        <table>
            <tr>
                <td>First Name:</td>
                <td><input type="text" name="firstname"></td>
            </tr>
            <tr>
                <td>Last Name:</td>
                <td><input type="text" name="lastname"></td>
            </tr>
            <tr>
                <td>Email:</td>
                <td><input type="text" name="email"></td>
            </tr>
            <tr>
                <td>Username:</td>
                <td><input type="text" name="username"></td>
            </tr>
            <tr>
                <td>Password:</td>
                <td><input type="password" name="password"></td>
            </tr>
        </table>
        <input type="submit" value="Register">
    </form>
    <br>
    
    Already have an account? <a href="login.jsp">Login here</a>

</body>
</html>