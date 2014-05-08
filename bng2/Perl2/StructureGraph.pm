# StructureGraph.pm, 
# used for creating visualizations of patterns and rules
# Author: John Sekar (johnarul.sekar@gmail.com)

package StructureGraph;
# pragmas
use strict;
use warnings;
no warnings 'redefine';

# Perl Modules
use Class::Struct;
use List::Util qw(min max sum);
#use List::MoreUtils qw( uniq);
use Data::Dumper;

# BNG Modules
use SpeciesGraph;

# Notes for self
# Only pass array and hash references to subroutines using \@ and \%
# Dereference using @{...} and %{...}

struct Node => 
{ 
	'Type' => '$', 
	#must be one of 'Mol', 'Comp', 'BondState', 'CompState', 'GraphOp', 'Rule'
	'Name' => '$', 
	'ID' => '$', #only one id is used for each node
	'Parents' => '@', 
	'Side' => '$',
	'Rule' => '$'
}; 

struct StructureGraph => { 'Type' => '$', 'NodeList' => '@' };

sub makeNode
{
	# input in this order Type, Name, ID, Parents, Side
	# type and name are compulsory, rest are not
	my $node = Node->new();
	$node->{'Type'} = shift @_;
	$node->{'Name'} = shift @_;
	$node->{'ID'} = @_ ? shift @_ : 0;
	$node->{'Parents'} = @_ ? shift @_ : ();
	$node->{'Side'} = @_ ? shift @_ : ();
	return $node;
}

sub makeStructureGraph
{
	# input is Type, NodeList
	my $psg = StructureGraph->new();
	$psg->{'Type'} = $_[0];
	$psg->{'NodeList'} = $_[1];
	return $psg;
}

sub printNode
{
	my $node = $_;
	my $string = $node->{'ID'};
	$string .= "\t\t";
	$string .= $node->{'Name'};
	if ($node->{'Parents'})
	{
		$string .= "\t\t";
		$string .= "(".join(",",@{$node->{'Parents'}} ).")";
	}
	
	if ($node->{'Side'})
	{
		$string .= "\t\t";
		$string .= $node->{'Side'};
	}
	return $string;
}

sub getNodeList
{
	my $sg = shift @_;
	if ($sg->{'NodeList'}) {return @{$sg->{'NodeList'}};}
	return ();
}


sub printGraph 
{
	my $psg = shift @_;
	my @string = map {printNode()} @{$psg->{'NodeList'}};
	return $psg->{'Type'}."\n".join("\n",@string);
}


sub makePatternStructureGraph
{
	my $sg = shift @_;
	my $index = @_ ? shift @_ : 0; # this is the index of the pattern in some list of patterns
	
	my @nodelist = ();
	
	if ( $sg->isNull() != 0) { return undef;}
	
	# Nodes for molecules, assigned the ID p.m, where p is the index of the pattern
	# index must be passed to this method.
	my $imol = 0;
	foreach my $mol ( @{$sg->Molecules} )
	{
		my $mol_id = $index.".".$imol;
		push @nodelist, makeNode('Mol',$mol->Name,$mol_id);
		
		# Nodes for components, assigned the ID p.m.c
		my $icomp = 0;
		foreach my $comp( @{$mol->Components} )
		{
			my $comp_id = $mol_id.".".$icomp;
			my @parents = ($mol_id);
			push @nodelist, makeNode('Comp',$comp->Name,$comp_id,\@parents);
			
			# Nodes for internal states, assigned the ID p.m.c.0
			if (defined $comp->State) 
				{ 
					my $state_id = $comp_id.".0";
					my @parents = ($comp_id);
					push @nodelist, makeNode('CompState',$comp->State,$state_id,\@parents);
				}
			
			# Nodes for each wildcard bond (either !? or !+), assigned the ID p.m.c.1
			if (scalar @{$comp->Edges} > 0) 
			{ 
				my $bond_state = ${$comp->Edges}[0];
				if ($bond_state =~ /^[\+\?]$/)
				{
					my $bond_id = $comp_id.".1";
					my @parents = ($comp_id);
					push @nodelist, makeNode('BondState',$bond_state,$bond_id,\@parents);	
				}
			}
			$icomp++;
		}
		$imol++;
	}
	# Nodes for each specified bond, assigned the ID p.m1.c1.1, 
	# where m1.c1 and m2.c2 are the bonded components, sorted. 
	# specified bonds are all assigned the same name "+"
	# only one id is used for each node
	if (scalar @{$sg->Edges} > 0) 
		{
			foreach my $edge (@{$sg->Edges}) 
				{ 
				my @comps = sort split(/ /,$edge);
				my $bond_id = $index.".".$comps[0].".1";
				my @parents = map {$index.".".$_} @comps;
				push @nodelist, makeNode('BondState',"+",$bond_id,\@parents);	
				}
		}
	my $psg = makeStructureGraph('Pattern',\@nodelist);
	#print $psg->printGraph();
	return $psg;	
}

# operations on structure graphs
sub combine
{
# appends an index to all nodes of each structure graph 
# then combines the structure graphs
	my @psg_list =  @{shift @_};
	my $index =  @_ ? shift @_ : "0";
	my $type = $psg_list[0]->{'Type'};
	my @nodelist = ();
	
	foreach my $i(0..@psg_list-1) 
		{ 
			my $psg = $psg_list[$i];
			#my $index = $indexlist[$i]; 
			#my @nodes = @{$psg->{'NodeList'}};
			my @nodes = getNodeList($psg);
			foreach my $node (@nodes)
				{
					my $id = $node->{'ID'};
					$node->{'ID'} = $index.".".$id;
					if (defined $node->{'Parents'})
						{ 
						my @parents_idlist = @{$node->{'Parents'}};
						my @parents_idlist_new = map {$index.".".$_} @parents_idlist;
						$node->{'Parents'} = \@parents_idlist_new;
						}
				}
			push @nodelist, @nodes;
		}	
	my $psg1 = makeStructureGraph($type,\@nodelist);
	return $psg1;
}
sub combine2
{
# trivially combines structure graphs
	my @psg_list =  @{shift @_};
	my $type = $psg_list[0]->{'Type'};
	my @nodelist = ();
	
	foreach my $i(0..@psg_list-1) 
		{ 
			my $psg = $psg_list[$i];
			my @nodes;
			if (defined $psg->{'NodeList'}) {@nodes = @{$psg->{'NodeList'}};}
			if (@nodes) { push @nodelist, @nodes; }
		}	
	my $psg1 = makeStructureGraph($type,\@nodelist);
	return $psg1;
}
sub findNode
{
	my @nodelist = @{shift @_};
	my $idcheck = shift @_;	
	my @nodes = grep ($_->{'ID'} eq $idcheck,@nodelist);
	if (@nodes) {return $nodes[0];} 
	return 0;
}

sub findNodes
{
	my @nodelist = @{shift @_};
	my @idlist = @{shift @_};
	my @nodes;
	foreach my $idcheck(@idlist)
		{
		my $node = findNode(\@nodelist,$idcheck);
		if ($node) { push @nodes, $node;}
		}
	return @nodes;
}

sub hasType
{
	my @nodelist = @{shift @_};
	my $type = shift @_;
	my @nodes = grep ( $_->{'Type'} eq $type, @nodelist);
	return @nodes;
}

sub hasSide
{
	my @nodelist = @{shift @_};
	my $side = shift @_;
	my @nodes = grep ( $_->{'Side'} eq $side, @nodelist);
	return @nodes;
}

sub hasParent
{
	my @nodelist = @{shift @_};
	my $parent_id = shift @_;
	my @nodes;
	foreach my $node (@nodelist)
		{
		if ($node->{'Parents'})
			{
			my @parents = @{$node->{'Parents'}};
			if (grep($_ eq $parent_id, @parents)) 
				{push @nodes, $node;}
			}
		}
	return @nodes;
}

sub hasParents
{
	my @nodelist = @{shift @_};
	my @parent_ids = @{shift @_};
	my @nodes;
	@nodes = @nodelist;
	foreach my $parent_id ( @parent_ids)
	{
		my @nodes2 = hasParent(\@nodes,$parent_id);
		if (@nodes2) { @nodes = @nodes2; }
		else { return (); }
	}
	return @nodes;
}

sub remapNode
{
	my $node = shift @_;
	my %remap = %{shift @_};
	my $id = $node->{'ID'};
	$node->{'ID'} = $remap{$id};
	if ($node->{'Parents'})
	{
		my @parents = @{$node->{'Parents'}};
		my @new_parents = sort map ( $remap{$_}, @parents);
		$node->{'Parents'} = \@new_parents;
	}
	if (defined $node->{'Rule'})
	{
	$node->{'Rule'} = $remap{$node->{'Rule'}};
	}
}

sub remapNodeList
{
	my @nodelist = @{shift @_};
	my %remap = %{shift @_};
	
	foreach my $node (@nodelist) { remapNode($node,\%remap); }
	return @nodelist;
}

sub mergeCorrespondent
{
	my %mapf = %{shift @_}; # these maps should have been modified and extended
	my %mapr = %{shift @_};

	my $reac = shift @_; # should be a combined structure graph of patterns
	my $prod = shift @_;
	
	my @reac_nodelist = @{$reac->{'NodeList'}};
	my @prod_nodelist = @{$prod->{'NodeList'}};
	
	# i.e. mapping correspondent IDs on both sides of a rule
	# to a single canonical ID
	my %idmap;
	while (my ($key, $value) = each %mapf)
	{
		$idmap{$key} = $key;
	}
	while (my ($key, $value) = each %mapr)
	{
		$idmap{$key} = ($value eq "-1") ? $key : $value;
	}

	my @nodelist = ();
	
	foreach my $node (@reac_nodelist)
	{
		#check if it has a correspondence
		if ($mapf{$node->{'ID'}} ne "-1")
			{
			remapNode($node,\%idmap);
			$node->{'Side'} = 'both';
			push @nodelist, $node;
			}
		else
			{
			remapNode($node,\%idmap);
			$node->{'Side'} = 'left';
			push @nodelist, $node;
			}
	}
	foreach my $node (@prod_nodelist)
	{
	if ($mapr{$node->{'ID'}} eq "-1")
			{
			remapNode($node,\%idmap);
			$node->{'Side'} = 'right';
			push @nodelist, $node;
			}
	}
	my $rsg = makeStructureGraph('Rule',\@nodelist);
	return $rsg;
}

sub addGraphOperations
{
	my $rsg = shift @_;
	my @nodelist = @{$rsg->{'NodeList'}};
	
	my $id = -1;
	
	# identify modified bonds
	my @bondstates = hasType(\@nodelist,'BondState');
	my @delbonds = hasSide(\@bondstates,'left');
	my @addbonds = hasSide(\@bondstates,'right');
	
	my @mols = hasType(\@nodelist,'Mol');
	my @left_mols = hasSide(\@mols,'left');
	my @right_mols = hasSide(\@mols,'right');
	
	my @compstates = hasType(\@nodelist,'CompState');
	my @left_compstates = hasSide(\@compstates,'left');
	my @right_compstates = hasSide(\@compstates,'right');

	# transcribing the graph operations in order
	# this order will be used later to process context
	# order: ChangeState, deletebond/deletemol, addbond/addmol
	
	foreach my $left_compstate (@left_compstates)
	{
		# find the partner on the right
		my $comp_id = ${$left_compstate->{'Parents'}}[0];
		my @partner = hasParent(\@right_compstates,$comp_id);
		# partner may not exist, in case of deletion
		if (@partner)
			{
				my $left_id = $left_compstate->{'ID'};
				my $right_id = $partner[0]->{'ID'};
				my $name = 'ChangeState';
				my @parents = ($left_id,$right_id);
				push @nodelist, makeNode('GraphOp',$name,++$id,\@parents);
			}
	}
	
	foreach my $bondstate(@delbonds)
	{
		my $bond_id = $bondstate->{'ID'};
		my $name = 'DeleteBond';
		my @parents = ($bond_id);
		push @nodelist, makeNode('GraphOp',$name,++$id,\@parents);
	}

	foreach my $mol (@left_mols)
	{
		my $mol_id = $mol->{'ID'};
		my $name = 'DeleteMol';
		my @parents = ($mol_id);
		push @nodelist, makeNode('GraphOp',$name,++$id,\@parents);
	}
	
	foreach my $bondstate(@addbonds)
	{
		my $bond_id = $bondstate->{'ID'};
		my $name = 'AddBond';
		my @parents = ($bond_id);
		push @nodelist, makeNode('GraphOp',$name,++$id,\@parents);
	}

	foreach my $mol (@right_mols)
	{
		my $mol_id = $mol->{'ID'};
		my $name = 'AddMol';
		my @parents = ($mol_id);
		push @nodelist, makeNode('GraphOp',$name,++$id,\@parents);
	}
	
	my $rsg1 = makeStructureGraph('Rule',\@nodelist);
	return $rsg1;
}

sub addRuleNode
{
	my $rsg = shift @_;
	my $index = shift @_;
	my $name = shift @_;
	
	my @nodelist = @{$rsg->{'NodeList'}};
	my %remap = map { $_->{'ID'} => $index.".".$_->{'ID'}} @nodelist;
	
	foreach my $node (@nodelist ) 
	{
		remapNode($node,\%remap);
		$node->{'Rule'} = $index;
	}
	my $node = makeNode('Rule',"R_".$name,$index);
	$node->{'Rule'} = $index;
	push @nodelist, $node;
	my $rsg1 = makeStructureGraph('Rule',\@nodelist);
	return $rsg1;
}

sub makeRuleStructureGraph
{
	# Get rule reactants and products and map
	my $rr = shift @_;
	my $index = @_ ? shift @_ : "0";
	my $name = @_ ? shift @_ : "0";

	#print $rr->toString();
	my @reac = @{$rr->Reactants};
	my @prod= @{$rr->Products};
	my %mapf = %{$rr->MapF};
	my %mapr = %{$rr->MapR};
	
	# the correspondence hash needs to be modified to add
	# reactant/product indexes to IDs
	%mapf = modifyCorrespondenceHash(\%mapf,0,1);
	%mapr = modifyCorrespondenceHash(\%mapr,1,0);
	
	
	# Make combined structure graphs of reactant and product patterns respectively
	my %ind_reac = indexHash(\@reac);
	my %ind_prod = indexHash(\@prod);
	
	my @reac_psg = map( makePatternStructureGraph($_,$ind_reac{$_}), @reac);
	my @prod_psg = map( makePatternStructureGraph($_,$ind_prod{$_}), @prod);
	
	my $reac_psg1 = combine(\@reac_psg,"0");
	my $prod_psg1 = combine(\@prod_psg,"1");
	
	# the correspondence hash needs to be extended 
	# to include component states & bonds
	my ($mapf1,$mapr1) = extendCorrespondenceHash(\%mapf,\%mapr,$reac_psg1,$prod_psg1);
	%mapf = %$mapf1;
	%mapr = %$mapr1;
	
	# merge the nodes to generate the 'implicit' rule structure graph
	my $rsg = mergeCorrespondent(\%mapf,\%mapr,$reac_psg1,$prod_psg1);
	
	# add the graph operation nodes to generate
	# the 'explicit' rule structure graph
	$rsg = addGraphOperations($rsg);
	$rsg = addRuleNode($rsg,$index,$name);
	return $rsg;	
}

# functions dealing with hashes
sub indexHash
{
	my %indhash;
	my @list = @{shift @_};
	foreach my $i(0..@list-1) { $indhash{$list[$i]}=$i; }
	return %indhash;
}

sub printHash
{
	my %hash = %{shift @_};
	my $string = "\n";
	while ( my ($key,$value) = each %hash)
	{
		$string .= "$key\t\t$value\n";
	}
	return $string;
}

sub modifyCorrespondenceHash
{
	# modifying existing keys in place not recommended?
	my %map = %{shift @_};
	my $ind1 = shift @_;
	my $ind2 = shift @_;
	my %map2;
	
	while ( my ($key,$value) = each %map)
	{
		my $key1 = $ind1.".".$key;
		my $value1 = ($value eq "-1") ? -1 : $ind2.".".$value;
		$map2{$key1} = $value1;
	}	
	return %map2;
}

sub extendCorrespondenceHash
{
	my %mapf = %{shift @_};
	my %mapr = %{shift @_};

	my $reac = shift @_; # should be a combined structure graph of patterns
	my $prod = shift @_;
	
	my @reac_nodelist = @{$reac->{'NodeList'}};
	my @prod_nodelist = @{$prod->{'NodeList'}};

	# filter the component states on both sides
	# find the corresponding component on the other side
	# see if it has a matching component state 
	
	my @reac_compstates = hasType($reac->{'NodeList'},'CompState');
	my @prod_compstates = hasType($prod->{'NodeList'},'CompState');
	foreach my $node(@reac_compstates)
	{
		my $reac_id = $node->{'ID'};
		my $reac_parent = ${$node->{'Parents'}}[0];
		my $prod_parent = $mapf{$reac_parent};
		if ($mapf{$reac_parent} ne "-1")
		{
			my $prod_parent = $mapf{$reac_parent};
			my $prod_id = $prod_parent.".0";
			my $node2 = findNode(\@prod_compstates,$prod_id); 
			#$node2 always exists, because we check that $mapf{...} has not returned -1
			if ($node->{'Name'} eq $node2->{'Name'})
					{
						$mapf{$reac_id} = $prod_id;
						$mapr{$prod_id} = $reac_id;
					}
		}
	}
	
	# filter the bond states on both sides
	my @reac_bondstates = hasType($reac->{'NodeList'},'BondState');
	my @prod_bondstates = hasType($prod->{'NodeList'},'BondState');
	foreach my $node (@reac_bondstates)
	{
		my $reac_id = $node->{'ID'};
		my $name = $node->{'Name'};
		my @reac_parents = @{$node->{'Parents'}};
		if (scalar @reac_parents == 1)
		{
			my $reac_parent =$reac_parents[0];
			if ($mapf{$reac_parent} ne "-1")
				{
					my $prod_parent = $mapf{$reac_parent};
					my @node2 = hasParent(\@prod_bondstates,$prod_parent);
					if (@node2 and $node2[0]->{'Name'} eq $name)
					{
						my $prod_id = $node2[0]->{'ID'};
						$mapf{$reac_id} = $prod_id;
						$mapr{$prod_id} = $reac_id;
					}
				}
		}
		elsif (scalar @reac_parents == 2)
		{
			if ($mapf{$reac_parents[0]} ne "-1" and $mapf{$reac_parents[0]} ne "-1")
				{
				my @prod_parents = sort map ( $mapf{$_}, @reac_parents);
				my @node2 = hasParents(\@prod_bondstates,\@prod_parents);
				if (@node2 and $node2[0]->{'Name'} eq $name)
					{
						my $prod_id = $node2[0]->{'ID'};
						$mapf{$reac_id} = $prod_id;
						$mapr{$prod_id} = $reac_id;
					}
				}
		}	
	}
	
	# fill out the assignments for the remaining nodes that were not assigned
	foreach my $node (@reac_nodelist)
	{
		if (! $mapf{$node->{'ID'}}) { $mapf{$node->{'ID'}} = "-1";}	
	}
	foreach my $node (@prod_nodelist)
	{
		if (! $mapr{$node->{'ID'}}) { $mapr{$node->{'ID'}} = "-1";}	
	}
	return (\%mapf,\%mapr);
}

sub makeAtomicPattern
{
	my @nodelist = @{shift @_};
	my $node = shift @_;
	
	my $type = $node->{'Type'};
	my $ap;
	if ($type eq 'CompState')
		{
		my $comp = findNode(\@nodelist,${$node->{'Parents'}}[0]);
		my $mol = findNode(\@nodelist,${$comp->{'Parents'}}[0]);
		my $string = $mol->{'Name'}."(".$comp->{'Name'}."~".$node->{'Name'}.")";
		$ap = ($node->{'Name'} ne '?') ?  $string : undef;
		}
	elsif ($type eq 'BondState')
		{
		my @comps = map (findNode(\@nodelist,$_), @{$node->{'Parents'}}) ;
		my @mols = map (findNode(\@nodelist,${$_->{'Parents'}}[0]), @comps) ;
		if (scalar @comps == 1)
			{
			# it's a wildcard
			my $string = $mols[0]->{'Name'}."(".$comps[0]->{'Name'}."!".$node->{'Name'}.")";
			$ap = ($node->{'Name'} ne '?') ?  $string : undef;
			}
		else
			{
			# it's a specified bond
			my $string1 = $mols[0]->{'Name'}."(".$comps[0]->{'Name'}."!1)";
			my $string2 = $mols[1]->{'Name'}."(".$comps[1]->{'Name'}."!1)";
			$ap = join(".", sort {$a cmp $b} ($string1,$string2));
			}
		}
	elsif ($type eq 'Comp')
		{
		# return the unbound state
		# is it really unbound? check it external to this method
		my $mol = findNode(\@nodelist,${$node->{'Parents'}}[0]);
		my $string = $mol->{'Name'}."(".$node->{'Name'}.")";
		$ap = $string;
		}
	elsif ($type eq 'Mol')
		{
		$ap = $node->{'Name'};
		}
	return $ap;
}
sub makeAtomicPatterns 
{ 
	my $nodelist = shift @_;
	my $nodes = shift @_;
	my @aps = map { makeAtomicPattern($nodelist,$_)} @$nodes; 
	return @aps;
}

sub makeTransformation
{
	my @nodelist = @{shift @_};
	my $node = shift @_;
	my $type = $node->{'Type'};
	my $name = $node->{'Name'};
	my $arrow = "->";
	my $comma = ",";
	my $tr;
	if ($type ne 'GraphOp') { return undef; }
	if ($name eq 'ChangeState')
		{
		my @comps = map (findNode(\@nodelist,$_), @{$node->{'Parents'}});
		my @left = grep( $_->{'Side'} eq 'left', @comps) ;
		my @right = grep( $_->{'Side'} eq 'right', @comps) ;
		my $leftstr = makeAtomicPattern(\@nodelist,$left[0]);
		my $rightstr = makeAtomicPattern(\@nodelist,$right[0]);
		$tr = $leftstr.$arrow.$rightstr;
		}
	elsif ($name eq 'AddBond')
		{
		my $bond = findNode(\@nodelist,${$node->{'Parents'}}[0]);
		my @comps = map (findNode(\@nodelist,$_), @{$bond->{'Parents'}});
		my @leftstr = map ( makeAtomicPattern(\@nodelist,$_),@comps);
		my $rightstr = makeAtomicPattern(\@nodelist,$bond);
		$tr = join($comma,@leftstr).$arrow.$rightstr;
		}
	elsif ($name eq 'DeleteBond')
		{
		my $bond = findNode(\@nodelist,${$node->{'Parents'}}[0]);
		my @comps = map (findNode(\@nodelist,$_), @{$bond->{'Parents'}});
		my @rightstr = map ( makeAtomicPattern(\@nodelist,$_),@comps);
		my $leftstr = makeAtomicPattern(\@nodelist,$bond);
		$tr = $leftstr.$arrow.join($comma,@rightstr);
		}
	elsif ($name eq 'AddMol')
		{
		my $mol = findNode(\@nodelist,${$node->{'Parents'}}[0]);
		my $name = makeAtomicPattern(\@nodelist,$mol);
		$tr = $arrow.$name;
		}
	elsif ($name eq 'DeleteMol')
		{
		my $mol = findNode(\@nodelist,${$node->{'Parents'}}[0]);
		my $name = makeAtomicPattern(\@nodelist,$mol);
		$tr = $name.$arrow;
		}
	return $tr;
}



1;
