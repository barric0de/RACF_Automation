package MyBank::HOST;

use Win32::OLE;
use MyBank::MySQL;
use 5.010;

our $secret = 'Neque porro quisquam est qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit...';

sub new {
	my ($class,$connection_name) = @_;
	my $connmgr = Win32::OLE->new("PCOMM.autECLConnMgr") or die "Fallo al crear PCOMM.autECLConnMgr : $!\n";
	my $session_info = $connmgr->{autECLConnList}->FindConnectionByName($connection_name);
	while (not $session_info){
		sleep(1);
		$connmgr->{autECLConnList}->Refresh();
		$session_info = $connmgr->{autECLConnList}->FindConnectionByName($connection_name);
	}
	 
	my ($session) = Win32::OLE->new("PCOMM.autECLSession");
	$session->SetConnectionByHandle( $session_info->{Handle});
	
	my $ECLOIA = $session->autECLOIA();
	die qq[Error while getting ECLOIA : $!] if not $ECLOIA;
	
	$ECLOIA->waitforappavailable(10000);
	my $ECLPS = $session->autECLPS();

	my $self = {
		conn => $connmgr, session => $session,
		ecloia => $ECLOIA, eclps => $ECLPS,
	};
	
	bless $self, $class;
	$self;
}

sub Start_Sessions{
	my $connmgr = Win32::OLE->new("PCOMM.autECLConnMgr") or die "Couldn't create PCOMM.autECLConnMgr : $!\n";
	$connmgr->StartConnection("profile=C:\\zOS_Production.ws connname=A");
	$connmgr->StartConnection("profile=C:\\zOS_PreProduction.ws connname=B");
	$connmgr->StartConnection("profile=C:\\zOS_Development.ws connname=C");
}

sub Check_Session_Is_Alive{
	my ($Session_Name,$Host) = @_;
	my $connmgr = Win32::OLE->new("PCOMM.autECLConnMgr") or die "Couldn't create PCOMM.autECLConnMgr : $!\n";
	my $session_info = $connmgr->{autECLConnList}->FindConnectionByName($Session_Name);
	if (not $session_info){
		$connmgr->StartConnection("profile=C:\\" . $Host . ".ws connname=" . $Session_Name);
		sleep(2);
	}
	
	if ($session_info->{CommStarted} != 1){
		my ($session) = Win32::OLE->new("PCOMM.autECLSession");
		$connmgr->{autECLConnList}->Refresh();
		$session_info = $connmgr->{autECLConnList}->FindConnectionByName($Session_Name);
		$session->SetConnectionByHandle( $session_info->{Handle});
		$session->StartCommunication();
	}
}

sub am_I_at_ISPF_Shell{
	my $self = shift;
	if ($self->checkForText('ISPF Command Shell','3','20')){
		return 0;
	}else{
		return 1;
	}
}

sub ecloia { 
	my ($self) = @_; 
	$self->{ecloia}; 
}
sub eclps { 
	my ($self) = @_;
	$self->{eclps}; 
}

sub cols { 
	my ($self) = @_;
	$self->eclps->NumCols; 
}
sub rows { 
	my ($self) = @_; 
	$self->eclps->NumRows; 
}

sub destroy { 
	system("PCOMSTOP /ALL");
	system("TASKKILL /F /IM pcsws.exe");
	system("TASKKILL /F /IM pcscm.exe");
}

sub wait {
	my ($self) = @_;
	while (not $self->ecloia->Ready) { sleep 1 };
	while ($self->ecloia->InputInhibited) { sleep 1 };
}

sub sendkeys {
	my $self = shift;
	$self->eclps->SendKeys(@_);
	$self->wait;
}

sub sendCommand{
	my @screen;
	my $self = shift;
	if ( $self->checkForText('ISPF Command Shell','3','31') ){
		$self->eclps->SendKeys(@_);
		$self->wait;
	}
}

sub screen {
	my ($self) = @_;
	my ($cols,$rows) = ($self->cols,$self->rows);
	my ($line) = $self->eclps->GetTextRect(1,1,$rows,$cols);
	my @lines;
	push @lines, $1 while ( $line =~ s/(^.{$cols})//);
	push @lines, $line if $line;
	@lines;
}

sub getTextIn {
	my $self = shift;
	return join '', $self->eclps->GetText('8,4,20');
}

sub checkForText{
	my ($self,$text,$row,$col) = @_;
	my $Output = $self->eclps->SearchText($text, 1, $row, $col);
	$Output;
}

sub find_field{
	my ($self,$row,$col,$value) = @_;
	my $field = $self->eclps->autECLFieldList->FindFieldByRowCol( $row,$col );
	$field->SetText($value);
}

sub dump {
	my ($self) = shift;
	print "$_\n" foreach ($self->screen);
}

sub field {
	my ($self,$index,$value) = @_;
	my $result = $self->eclps->autECLFieldList($index)->GetText();
	$self->eclps->autECLFieldList($index)->SetText($value) if (scalar @_ == 3);
	$result;
}

sub get_set_field {
	my $self = shift;
	my $field = shift;
	my $result;
	if (defined wantarray) {
		$result = $field->GetText();
	};
	if (@_) {
		$field->SetText(@_);
		$self->log("Setting field to @_");
	};
	$result;
}

sub field_by_index {
	my $self = shift;
	my $index = shift;
	my @fields = $self->fields;
	my $field = $fields[ $index ];
	$self->get_set_field($field,@_);
}

sub WriteInIndex {
	my $self = shift;
	my $index = shift;
	my @fields = $self->fields;
	my $field = $fields[ $index ];
	$self->get_set_field($field,@_);
}

sub get_LastActionData{
	my $self = shift;
	$self->{LastAction_Data} eq '' ? undef : $self->{LastAction_Data};
}

sub get_ResultType{
	my $self = shift;
	$self->{LastAction_ResultType} eq '' ? undef : $self->{LastAction_ResultType};
}

sub get_Message{
	my $self = shift;
	$self->{LastAction_ResultType} eq '' ? undef : $self->{LastAction_Message};
}

sub WriteLoginStatus{
	my ($self,$status) = @_;
	$self->{LoginStatus}=$status;
}

sub is_error{
	my $self = shift;
	$self->get_ResultType eq 'ERROR' ? 1 : 0;
}

sub loggedIn{
	my $self = shift;
	$self->{LoginStatus} eq 'True' ? 1 : 0;
}

1;