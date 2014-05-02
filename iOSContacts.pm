package iOSContacts;

#use base 'Exporter';
#our @EXPORT_OK = qw(new get_contacts_db_filename);

use DBI;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);
use Data::Dumper;
use Term::ANSIColor;

sub new
{
    my ($class, $params) = @_;
    my $self = {
        _backup_directory => $params->{backup_directory},
        _contacts_db_filename => '31bb7ba8914766d4ba40d6dfb6113c8b614be442',
        _contacts_db => undef,
        _contacts => undef
    };
    
    unless (-d $self->{_backup_directory}){
        die 'Directory does not exist';
    }
    
    bless $self, $class;
    $self->_generate_contacts();
    return $self;
}

sub _generate_contacts {
    my ($self) = @_;
    return $self->{_contacts} if (defined $self->{_contacts});

    my $dbh = $self->connect_db();
    my $sql = qq|SELECT First, Last, value FROM ABMultiValue, ABPerson WHERE record_id = ROWID AND value is not null|;
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my $numbers = {};
    while (my $number = $sth->fetchrow_hashref) {
        my $unique_id = $self->normalize_unique_value($number->{'value'});
        $numbers->{$unique_id} = {'first_name' => $number->{'First'}, 'last_name' => $number->{'Last'}};
    } 
    $self->{_contacts} = $numbers;
}

sub get_contacts{
    my ($self) = @_;
    return $self->{_contacts};
}

sub get_contact_for_unique_id {
    my ($self, $unique_id) = @_;
    $unique_id = $self->normalize_unique_value($unique_id);
    my $contact = $self->{_contacts}->{$unique_id};
    return $contact;
}

# Internal methods 
sub connect_db {
    my ($self) = @_;
    $sms_file = $self->{_backup_directory}.$self->{_contacts_db_filename};
    die "no file at $sms_file" unless (-e $sms_file);
    
    $self->{_contacts_db} = DBI->connect( 
        "dbi:SQLite:dbname=$sms_file", 
        "",                          
        "",                          
        { RaiseError => 1 },         
    ) or die $DBI::errstr;
    return $self->{_contacts_db};
}

sub normalize_unique_value{
    my ($self, $value) = @_;

    if ($value =~ /\@/){
        # Email
        return $value;
    } elsif ($value =~ /^http/) {
        # Web address
        return $value
    } elsif ($value =~ /^itunes/){
        # iTunes ringtone
        return undef;
    } else {
        # Should be a phone number
        $value =~ s/\D//g;
        $value = "1".$value if $value =~ /^\d{10}$/;
        $value = "+".$value;
        return $value;
        #print colored("$value should be a number\n", 'yellow');
        #print color 'reset';
    }
}
return 1; 
