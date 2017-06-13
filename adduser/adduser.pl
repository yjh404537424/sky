#!/usr/bin/perl



use strict;
use Data::Dumper;
use Getopt::Long;
use File::Copy;


use constant {
    DEFAULT_GROUP => "users",
    DEFAULT_GID => '100',
    DEFAULT_SHELL => '/bin/bash'
};


my ($host, $help, $user, $as, $debug, $sudo);

sub runCommand
{
    my $cmd = shift;
    print "INFO>> run $cmd\n" if $debug;
    return system($cmd);
}

sub collectUserInfo
{
    my ($user, $command) = @_;
    my $uid = getUid($user);
    my $pwd = getCurrentPassword($user);
    my $shell = DEFAULT_SHELL;
    my $gid = DEFAULT_GID;

    my $file = "/tmp/___local_{$user}_user";
    runCommand("echo '$user:$uid:$gid:$shell:$pwd' > $file");

    my $src = "/home/$user/.ssh/id_rsa.pub";
    my ($src1, $src2) = ("/home/$user/.ssh/identity.pub", "/home/$user/.ssh/authorized_keys");
    $file = "/tmp/___local_{$user}_ssh_pubkey";
    runCommand("/usr/bin/sudo -u $user /bin/bash -c 'pubkey_file=; for i in $src $src1 $src2; do if [ -e \$i ]; then pubkey_file=\$i; break; fi; done; if [ x\"\$pubkey_file\" = x ]; then /usr/bin/ssh-keygen -N \"\" -t rsa -f /home/$user/.ssh/id_rsa; /bin/cp $src $file; else cp \$pubkey_file $file; fi;'");

    $src = "/home/$user/.bash_profile";
    $file = "/tmp/___local_{$user}_bash_profile";
    runCommand("if [ -e $src ]; then /bin/cp $src $file; fi;");

    $src = "/home/$user/.vimrc";
    $file = "/tmp/___local_{$user}_vimrc";
    runCommand("if [ -e $src ]; then /bin/cp $src $file; fi;");

    $src = $command;
    $file = "/tmp/___local_{$user}_adduser.pl";
    runCommand("/bin/cp $src $file");
}

sub addUser
{
    my ($user, $sudo) = @_;
    my $info = `cat /tmp/___local_{$user}_user`;
    chomp $info;
    my ($un, $uid, $gid, $shell, $pwd) = split /:/, $info, 5;
    my $localUid = getUid($user);

    my $cmd = ($localUid == '' ? "/usr/sbin/useradd" : "/usr/sbin/usermod") . " -g " . $gid;
    $cmd = $cmd . " -p '" . $pwd . "' -s " . $shell . " -u " . $uid . " $user";
    runCommand($cmd);

    $cmd = "if [ ! -e /home/$user/.ssh ]; then sudo -u $user mkdir -p /home/$user/.ssh/; fi";
    runCommand($cmd);

    $cmd = "sudo -u $user /bin/cp /tmp/___local_{$user}_ssh_pubkey /home/$user/.ssh/authorized_keys";
    runCommand($cmd);

    $cmd = "sudo -u $user /bin/cp /tmp/___local_{$user}_vimrc /home/$user/.vimrc";
    runCommand($cmd);

    $cmd = "sudo -u $user /bin/cp /tmp/___local_{$user}_bash_profile /home/$user/.bash_profile";
    runCommand($cmd);
    
    $cmd = "rm -rf /tmp/___local_{$user}_*";
    runCommand($cmd);

    addSudo($user) if $sudo;
}

sub addSudo
{
    my ($user) = @_;

    my $file = "/etc/sudoers"; 
    my $tmp = "/tmp/___local_sudoers";
    if( -e $tmp) {
        print STDERR "ERROR>> There is another program running, please try again later\n";
        exit;
    }
    copy($file, $tmp);

    open F, "<$tmp" or die "Cann't open $tmp for reading\n";
    my @lines = <F>;
    close F;
    
    my ($hasAdmins, $hasUser, $hasDefinePrivilege, $sharp, $modify) = (0, 0, 0, '#', 0);
    $hasAdmins = grep(/^\s*User_Alias\s+ADMINS\s*=/, @lines);
    $hasDefinePrivilege = grep(/^\s*ADMINS\s+ALL\s*=/, @lines);
    $sharp = '' if $hasAdmins;

    $hasUser = grep(/^$sharp\s*User_Alias\s+ADMINS\s*=[\w,\s]*[\s,]$user[\s,]/, @lines);

    print "INFO>> User $user is in the sudoers \n" if ($hasUser and $debug);

    open OF, ">$tmp.new" or die "Cann't open $tmp.new for writing\n";
    for my $line (@lines) {
        if(!$hasUser and $line =~ /^$sharp\s*User_Alias\s+ADMINS\s*=(.*)/) {
            print "INFO>> add user $user to sudoers \n" if $debug;
            print OF "User_Alias ADMINS =$1, $user\n";
            $modify = 1;
        } else {
            print OF $line;
        }
    }

    if(!$hasDefinePrivilege) {
        print OF "ADMINS ALL=(ALL) ALL\n";
        $modify = 1;
    }
    close OF;

    # we will copy back, only the file has been changed.
    if($modify) {
        copy($tmp . ".new", $file);
        runCommand("/bin/chmod 440 $file");
    }

    unlink $tmp;
    unlink $tmp . ".new";
}

sub getUid 
{
    my $user = shift;
    my $uid = `/usr/bin/id -u $user`;
    chomp $uid;
    return $uid;
}

sub getCurrentPassword
{
    my $user = shift;
    my $pwd = `sudo /bin/grep '^$user:' /etc/shadow|/bin/awk -F: '{print \$2;}'`;
    chomp $pwd;
    return $pwd;
}

sub addGroup
{
    my $group = shift;
}

sub syncFile
{
    my ($file, $remoteFile, $host, $as) = @_;
    $as = $as . '@' if $as;
    runCommand("/usr/bin/scp -r $file $as$host:$remoteFile");
}

sub runRemoteCommand
{
    my ($cmd, $host, $as) = @_;
    $as = $as . '@' if $as;
    my $installSudo = "if [ ! -x /usr/bin/sudo ]; then yum install -y sudo vim rsync ; fi; ";
    runCommand("/usr/bin/ssh -t $as$host '$installSudo /usr/bin/sudo $cmd'");
}

sub usage
{
    my $cmd = shift;
    print "Usage: $cmd -help | -host <host> | -user <user> | -as <user>  | -sudo\n";
    print "  -help : print this help manual\n";
    print "  -host <host>: specific the host\n";
    print "  -user <user>: specific the username\n";
    print "  -as <user>: optional, login host as <user>\n";
    print "  -sudo : add the sudo privilege\n";
    exit;
}

sub remoteAddUser
{
    my ($user, $host, $as, $sudo) = @_;
    my $cmd = "/tmp/___local_{$user}_adduser.pl -host localhost -user $user";
    $cmd = ($cmd . " -debug ") if $debug;
    $cmd = ($cmd . " -sudo ") if $sudo;
    runRemoteCommand($cmd, $host, $as);
}

sub clearUserInfo
{
    my ($user, $host, $as) = @_;
    runCommand("/usr/bin/sudo /bin/rm -rf /tmp/___local_{$user}_*");
}

sub syncFileToRemote
{
    my ($user, $host, $as) = @_;
    syncFile("/tmp/___local_{$user}_*", "/tmp/", $host, $as);
}


GetOptions ("host=s" => \$host,
            "user=s" => \$user,
            "as=s" => \$as,
            "help" => \$help,
            "sudo" => \$sudo,
            "debug" => \$debug);

usage if $help;
usage if !$user || !$host;

if($host eq '127.0.0.1' || $host eq 'localhost') {
    addUser($user, $sudo);
    exit;
}

collectUserInfo($user, $0);
syncFileToRemote($user, $host, $as);
remoteAddUser($user, $host, $as, $sudo);
clearUserInfo($user, $host, $as);
