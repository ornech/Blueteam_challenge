user@debian:~/Blueteam_challenge/infrastructure$ ./init_dvwa.sh 
[+] Waiting for MySQL in container lab1_mariadb to accept TCP connections...
[+] lab1_mariadb ready.
[*] Initialising DVWA for lab1 (DVWA container: lab1_dvwa, attacker: lab1_attacker)...
[attacker] TOKEN=9af6d371b82d1cd4d81fb866105ac172
---- RESULT ----

			<div id="main_body">

				
<div class="body_padded">
	<h1>Database Setup <img src="dvwa/images/spanner.png" /></h1>

	<p>Click on the 'Create / Reset Database' button below to create or reset your database.<br />
	If you get an error make sure you have the correct user credentials in: <em>/var/www/html/config/config.inc.php</em></p>

	<p>If the database already exists, <em>it will be cleared and the data will be reset</em>.<br />
	You can also use this to reset the administrator credentials ("<em>admin</em> // <em>password</em>") at any stage.</p>
	<hr />
--

	<br /><br /><br />

	<!-- Create db button -->
	<form action="#" method="post">
		<input name="create_db" type="submit" value="Create / Reset Database">
		<input type='hidden' name='user_token' value='7260b27bcedd4dcff2a71a4a656b9d8c' />
	</form>
	<br />
	<hr />
</div>
				<br /><br />
				<div class="body_padded"><div class="message">Database has been created.</div><div class="message">'users' table was created.</div><div class="message">Data inserted into 'users' table.</div><div class="message">'guestbook' table was created.</div><div class="message">Data inserted into 'guestbook' table.</div><div class="message">Backup file /config/config.inc.php.bak automatically created</div><div class="message"><em>Setup successful</em>!</div><div class="message">Please <a href='login.php'>login</a>.<script>setTimeout(function(){window.location.href='login.php'},5000);</script></div><div class="message">Database has been created.</div><div class="message">'users' table was created.</div><div class="message">Data inserted into 'users' table.</div><div class="message">'guestbook' table was created.</div><div class="message">Data inserted into 'guestbook' table.</div><div class="message">Backup file /config/config.inc.php.bak automatically created</div><div class="message"><em>Setup successful</em>!</div><div class="message">Please <a href='login.php'>login</a>.<script>setTimeout(function(){window.location.href='login.php'},5000);</script></div></div>

			</div>

			<div class="clear">
			</div>
[*] Checking tables in lab1_mariadb...
Tables_in_dvwa
guestbook
users
==========================================
[+] Waiting for MySQL in container lab2_mariadb to accept TCP connections...
[+] lab2_mariadb ready.
[*] Initialising DVWA for lab2 (DVWA container: lab2_dvwa, attacker: lab2_attacker)...
[attacker] TOKEN=57f2349b8ef8cfc4e36e4832ff6bcb26
---- RESULT ----

			<div id="main_body">

				
<div class="body_padded">
	<h1>Database Setup <img src="dvwa/images/spanner.png" /></h1>

	<p>Click on the 'Create / Reset Database' button below to create or reset your database.<br />
	If you get an error make sure you have the correct user credentials in: <em>/var/www/html/config/config.inc.php</em></p>

	<p>If the database already exists, <em>it will be cleared and the data will be reset</em>.<br />
	You can also use this to reset the administrator credentials ("<em>admin</em> // <em>password</em>") at any stage.</p>
	<hr />
--

	<br /><br /><br />

	<!-- Create db button -->
	<form action="#" method="post">
		<input name="create_db" type="submit" value="Create / Reset Database">
		<input type='hidden' name='user_token' value='8b47a95d4ae60021283ca4ef4024d13b' />
	</form>
	<br />
	<hr />
</div>
				<br /><br />
				<div class="body_padded"><div class="message">Database has been created.</div><div class="message">'users' table was created.</div><div class="message">Data inserted into 'users' table.</div><div class="message">'guestbook' table was created.</div><div class="message">Data inserted into 'guestbook' table.</div><div class="message">Backup file /config/config.inc.php.bak automatically created</div><div class="message"><em>Setup successful</em>!</div><div class="message">Please <a href='login.php'>login</a>.<script>setTimeout(function(){window.location.href='login.php'},5000);</script></div></div>

			</div>

			<div class="clear">
			</div>
[*] Checking tables in lab2_mariadb...
Tables_in_dvwa
guestbook
users
==========================================
[+] Waiting for MySQL in container lab3_mariadb to accept TCP connections...
[+] lab3_mariadb ready.
[*] Initialising DVWA for lab3 (DVWA container: lab3_dvwa, attacker: lab3_attacker)...
[attacker] TOKEN=98ef69ce07818eebb376467fd468ebe6
---- RESULT ----

			<div id="main_body">

				
<div class="body_padded">
	<h1>Database Setup <img src="dvwa/images/spanner.png" /></h1>

	<p>Click on the 'Create / Reset Database' button below to create or reset your database.<br />
	If you get an error make sure you have the correct user credentials in: <em>/var/www/html/config/config.inc.php</em></p>

	<p>If the database already exists, <em>it will be cleared and the data will be reset</em>.<br />
	You can also use this to reset the administrator credentials ("<em>admin</em> // <em>password</em>") at any stage.</p>
	<hr />
--

	<br /><br /><br />

	<!-- Create db button -->
	<form action="#" method="post">
		<input name="create_db" type="submit" value="Create / Reset Database">
		<input type='hidden' name='user_token' value='8b486105cf26c8f871489afa7d3d3d9e' />
	</form>
	<br />
	<hr />
</div>
				<br /><br />
				<div class="body_padded"><div class="message">Database has been created.</div><div class="message">'users' table was created.</div><div class="message">Data inserted into 'users' table.</div><div class="message">'guestbook' table was created.</div><div class="message">Data inserted into 'guestbook' table.</div><div class="message">Backup file /config/config.inc.php.bak automatically created</div><div class="message"><em>Setup successful</em>!</div><div class="message">Please <a href='login.php'>login</a>.<script>setTimeout(function(){window.location.href='login.php'},5000);</script></div></div>

			</div>

			<div class="clear">
			</div>
[*] Checking tables in lab3_mariadb...
Tables_in_dvwa
guestbook
users
==========================================
[+] All done.
