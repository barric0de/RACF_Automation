# RACF_Automation
Automation of IBM Personal Comunications via Pcomm API

To automate tasks related to RACF Security through a web application, i’ve used a structure like this:
 

Web Application: HTTP forms where you define the actions that you want to automate. Everything that you can do through ISPF panels, could be automatable. In my case, the users can, among others, submit JCL jobs(predefined templates), modify user’s group membership, or create new users accounts.

Tasks database: A connector between the web Application and the RACF Listener. It’s something like a queue system that users two different databases: 
-	racf_operations_inbox : Jobs waiting to be processed
-	racf_operations_outbox: Jobs processed and info (return codes, output)

RACF Listener: A service that reads from Tasks database and processes the incoming  tasks. The service manipulates the 3270 screen from IBM Personal Comunications (https://www.ibm.com/developerworks/downloads/r/pcomm/) and interacts with him. Also, when a task is processed it writes the return code and output to the Tasks database. I’ve done this with the IBM Pcomm API(https://www-01.ibm.com/software/network/pcomm/library/)
Please, note that this requires a lot of customization to work: First of all, you need to identify the coordinates of every ISPF panel that you wanna recognize. Also, you need to specify where are the result of the execution, and do some error control.
