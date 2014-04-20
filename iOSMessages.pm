package iOSMessages;

sub new
{
    my ($class, $params) = @_;
    my $self = {
        _backup_directory => $params->{backup_directory},
        _sms_db_filename => '31bb7ba8914766d4ba40d6dfb6113c8b614be442',
        _messages => undef
    };

    unless (-d $self->{_backup_directory}){
        die 'Directory does not exist';
    }

    bless $self, $class;
    return $self;
}
