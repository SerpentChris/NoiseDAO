# Members can propose ways to spend funds and sponsor new members.
# Any member can veto a proposal or a sponsored member.
# Members can sponsor a new member or submit a proposal (not both) once a week.


struct Member:
    # sponsor is the address of the Member who sponsored this Member,
    sponsor: address
    # handle is a UTF8 encoded nickname that this Member goes by.
    handle: bytes32
    # time_joined is the timestamp of the block in which this member was sponsored.
    time_joined: timestamp
    # last_change is the timestamp of the block in which this member last sponsered a new member or made a new proposal.
    last_change: timestamp


struct Proposal:
    # sponsor is the address of the member who submitted this proposal
    sponsor: address
    # url is a UTF8 link to the full proposal specification
    url: bytes32[4]
    # digest is the sha3_256 digest of the proposal.
    digest: bytes32
    # wallet is the address to send funds to for this proposal.
    wallet: address
    # value is the amount of wei to send to the wallet
    value: uint256

NewMember: event({_sponsor: indexed(address), _address: indexed(address)})
NewProposal: event({_sponsor: indexed(address), _digest: indexed(bytes32)})
NewDonation: event({_donor: indexed(address), _value: indexed(wei_value)})

# key for members is the member's address
members: public(map(address, Member))
handle_taken: public(map(bytes32, bool))
# key for proposals is the hash of the Proposal struct members.
proposals: public(map(bytes32, Proposal))

WEEK_IN_SECONDS: constant(timedelta) = 60*60*24*7


@private
def check_member(member: address, current_time: timestamp):
    assert self.members[member].sponsor != ZERO_ADDRESS, 'address is not a member'
    assert (current_time - self.members[member].last_change) >= WEEK_IN_SECONDS, 'last change too recent'


@public
def sponsor_member(_address: address, _handle: bytes32):
    sponsor_address: address = msg.sender
    current_time: timestamp = block.timestamp
    self.check_member(sponsor_address, current_time)
    
    # make sure the proposed member address is not already used by a member
    assert self.members[_address].sponsor == ZERO_ADDRESS, 'address already taken'
    # make sure the handle isn't already used
    assert not self.handle_taken[_handle], 'handle already taken'

    self.members[_address] = Member(
        {
            sponsor: sponsor_address,
            handle: _handle,
            time_joined: current_time,
            last_change: 0,
        }
    )

    self.handle_taken[_handle] = True
    self.members[sponsor_address].last_change = current_time
    log.NewMember(sponsor_address, _address)


    return 

@public
def submit_proposal(_url: bytes32[4], _digest: bytes32, _wallet: address, _value: uint256):
    sponsor_address: address = msg.sender
    current_time: timestamp = block.timestamp
    self.check_member(sponsor_address, current_time)

    p: Proposal = Proposal({
        sponsor: sponsor_address,
        url: _url,
        digest: _digest,
        wallet: _wallet,
        value: _value
    })

    p_hash: bytes32 = keccak256(
        concat(
            convert(p.sponsor, bytes32),
            p.url[0],
            p.url[1],
            p.url[2],
            p.url[3],
            p.digest,
            convert(p.wallet, bytes32),
            convert(p.value, bytes32)
            )
    )

    self.members[sponsor_address].last_change = block.timestamp
    self.proposals[p_hash] = p
    log.NewProposal(sponsor_address, p_hash)


@public
@payable
def donate():
    value: wei_value = msg.value
    assert value > 0, 'empty donation'
    log.NewDonation(msg.sender, value)
