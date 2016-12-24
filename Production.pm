package MyBank::HOST::Production;

use base 'MyBank::HOST';
use MyBank::CredentialManager;
use 5.010;

sub login{
	my $self = shift;
	
	my $conn_Args = _Get_Credentials('Production');
	if ( $self->checkForText('Access to the TPX service','6','4') ){ 
		$self->sendkeys("$conn_Args->{usr}");
		$self->sendkeys("[ENTER]");
		$self->sendkeys("$conn_Args->{pwd}");
		$self->sendkeys("[ENTER]");
	}
	if ( $self->checkForText('at panel  TSP0041 with terminal','1','26') ){ 
		$self->sendkeys("[ENTER]");
		$self->sendkeys("tso_A");
		$self->sendkeys("[ENTER]");
		$self->sendkeys("$conn_Args->{usr}");
		$self->sendkeys("[ENTER]");
		$self->sendkeys("$conn_Args->{pwd}");
		$self->sendkeys("[ENTER]");
	}else{
		$self->log_event("ERROR","Error en logon: Step 2")
	}
	if ( $self->checkForText('Entering to HOST environment','4','5') ){ 
		$self->sendkeys("[ENTER]");
	}
	if ( $self->checkForText('Entering to HOST environment','4','5') ){ 
		$self->sendkeys("[ENTER]");
	}
	
	#######################Errors
	
	#Incorrect password : 
	if ( $self->checkForText('PASSWORD NOT AUTHORIZED FOR USERID','2','11') ){
		$self->sendkeys("[PF3]");
		$self->sendkeys("[PF12]");
		$self->log_event("ERROR","Incorrect password") and return;
	}
	#Too many attempts : 
	if ( $self->checkForText('LOGON REJECTED, TOO MANY ATTEMPS','1','11') ){
		$self->sendkeys("[PF12]");
		#$self->destroy;
		$self->log_event("ERROR","LOGON REJECTED, TOO MANY ATTEMPS") and return;
		
	}
	#Usuario revocado : 
	if ( $self->checkForText('LOGON REJECTED, RACF TEMPORARILY REVOKING USER ACCESS','1','11') ){
		$self->sendkeys("[PF12]");
		#$self->destroy;
		$self->log_event("ERROR","LOGON REJECTED, RACF TEMPORARILY REVOKING USER ACCESS") and return;
	}
	if ( $self->checkForText('already logged','1','41') ){
		$self->sendkeys("[PF12]");
		#$self->destroy;
		$self->log_event("ERROR","User is logged in. Please, disconnect the session") and return;
	}
	
	#######################
    
	if ( $self->checkForText('LOGON IN PROGRESS','2','8') ){
		$self->sendkeys("[ENTER]");	
		$self->sendkeys("6");	
		$self->sendkeys("[ENTER]");	
		$self->text_log('[-]Succesfully logged in :)');
		print "<p>[-]Authenticated. Host waiting orders ;-)</p>";
		$self->log_event("OK","Host Waiting Orders");
		return("OK","Host Waiting Orders");
	}
	
}

sub logoff{
	my $self = shift;
	if ( $self->checkForText('ISPF Command Shell','3','31') ){ 
		$self->sendkeys("[PF3]");
	} 
	if ( $self->checkForText('Main Host','1','3') ){ 
		$self->sendkeys("x");
		$self->sendkeys("[ENTER]");
	}
		
	if ( $self->checkForText('Specify Disposition of Log Data','1','21') ){
		$self->sendkeys("2");
		$self->sendkeys("[ENTER]");
	}
	if ( $self->checkForText('READY','1','2') ){ 
		$self->sendkeys("logoff");
		$self->sendkeys("[ENTER]");
	}
}
sub add_user_to_group{
	my ($self,$user,$group) = @_;
	$self->remove_user_from_group($user,$group);
	my $tso_command = "tso co $user group($group)";
	$self->sendkeys($tso_command);
	$self->sendkeys("[ENTER]");
	#ICH02005I - userid CONNECTION NOT MODIFIED
	if ( $self->checkForText('CONNECTION NOT MODIFIED','29','10') ){
		$self->sendkeys("[ENTER]");
		return ("ERROR","User $user is member of $group");
	}
	elsif ($self->checkForText('INVALID USERID','29','2') ){
		$self->sendkeys("[PA1]");
		$self->sendkeys("[ENTER]");
		$self->sendkeys("[ENTER]");
		return ("ERROR","User $user does not exists in RACF");
	}
	elsif ($self->checkForText('NAME NOT FOUND IN RACF DATA SET ','29','2') ){
		$self->sendkeys("[ENTER]");
		return ("ERROR","Group $group does not exists in RACF");
	}
	else{
		$self->sendkeys("[ENTER]");
		return ("OK","User $user added successfully to group $group");
	}
}
1;