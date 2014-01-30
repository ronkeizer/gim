use Net::Amazon::EC2;

 my $ec2 = Net::Amazon::EC2->new(
        AWSAccessKeyId => 'AKIAJT42FBQDTRUD5T3A', 
        SecretAccessKey => 'SECRET_KEY_HERE'
 );

 # Start 1 new instance from AMI: ami-XXXXXXXX
 my $instance = $ec2->run_instances(ImageId => 'ami-a87159ed', MinCount => 1, MaxCount => 1);

 my $running_instances = $ec2->describe_instances;

 foreach my $reservation (@$running_instances) {
    foreach my $instance ($reservation->instances_set) {
        print $instance->instance_id . "\n";
    }
 }

 my $instance_id = $instance->instances_set->[0]->instance_id;

 print "$instance_id\n";

 # Terminate instance

 my $result = $ec2->terminate_instances(InstanceId => $instance_id);