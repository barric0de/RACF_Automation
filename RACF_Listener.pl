#!Perl

use MyBank::MySQL;
use MyBank::HOST;
use MyBank::HOST::zOS_Production;
use MyBank::HOST::zOS_PreProduction;
use MyBank::HOST::zOS_Development;
use 5.010;

$|++;

while (1){
	my %Tasks = ();
	my $dbh = MyBank::MySQL->connect();
	$sth = $dbh->prepare('SELECT id,host,action,user,zgroup,submitter FROM racf_operations_inbox ORDER BY id') or die("Couldn't prepare statement: " . $dbh->errstr);
	$sth->execute;
	while( my ($id,$host,$action,$user,$zgroup,$submitter) = $sth->fetchrow_array ){
		$Tasks{$id}->{$host}={
			action => $action,
			host => $host,
			user => $user,
			group => $zgroup,
			submitter => $submitter,
		};
	}
	$sth->finish;
	
	foreach my $taskid ( sort keys %Tasks ){	
		foreach my $host ( sort keys %{ $Tasks{$taskid} } ){
			given($host){
				when('Production'){
					$Mainframe = MyBank::HOST::zOS_Production->new('A');
				}
				when('PreProduction'){
					$Mainframe = MyBank::HOST::zOS_PreProduction->new('B');
				}
				when('Development'){
					$Mainframe = MyBank::HOST::zOS_Development->new('C');
				}
			}
			$Mainframe->login();
			foreach my $chunk ( sort keys %{ $Tasks{$taskid}->{$host} } )	{
				if ( $Tasks{$taskid}->{$host}->{$chunk}->{action} eq 'GROUPADD' ){
					($ResultType,$Ret_Message) = $Mainframe->add_user_to_group(
						$Tasks{$taskid}->{$host}->{user},
						$Tasks{$taskid}->{$host}->{group}
					);
						
					my $sth = $dbh->prepare('INSERT INTO racf_operations_outbox (id,host,action,user,zgroup,submitter,revokedate,ResultType,message,chunk) VALUES (?,?,?,?,?,?,?,?,?,?)');
					$sth->execute(
						$taskid,
						$host,
						$Tasks{$taskid}->{$host}->{$chunk}->{action},
						$Tasks{$taskid}->{$host}->{$chunk}->{user},
						$Tasks{$taskid}->{$host}->{$chunk}->{group},
						$Tasks{$taskid}->{$host}->{$chunk}->{submitter},
						$ResultType,
						$Ret_Message,
						$chunk
					);
					$sth->finish;
				}
				$sth = $dbh->prepare('DELETE FROM racf_operations_inbox WHERE id = ?') or die("Couldn't prepare statement: " . $dbh->errstr);
				$sth->execute($taskid);
				$sth->finish;
			}
		}
		$Mainframe->logoff();
		$Mainframe->destroy();
	}
	$dbh->disconnect;
	sleep(5);
}
__END__