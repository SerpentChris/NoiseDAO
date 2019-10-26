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
    # url is a link to the full proposal specification
    url: string[100]
    # digest is the sha3_256 digest of the proposal.
    digest: bytes32
    # wallet is the address to send funds to for this proposal.
    wallet: address
    # value is the amount of wei to send to the wallet
    value: uint

NewMember: event({_sponsor: indexed(address), _address: indexed(address), _handle: indexed(bytes32)})
NewProposal: event({_sponsor: indexed(address), _digest: indexed(bytes32)})

members: public(mapping(address, Member))
handle_taken: public(mapping(bytes32, bool))
proposals: public(mapping(address, Proposal))
WEEK_IN_SECONDS: constant(uint) = 60*60*24*7


def __init__():
    # self.member_count = N # this is the nber of initial Members
    # self.members[0] = Member({addr: 0x..., sponsor: self, handle: b"Bob"})


@public
def sponsor_member(_address: address, _handle: bytes32):
    sponsor_address: address = msg.sender
    sponsor: Member = self.members[sponsor_address]
    current_time: timestamp = block.timestamp
    
    # make sure the sponsor is a member by checking their sponsor is nonzero.
    assert(sponsor.sponsor != 0, 'msg.sender is not a member')
    # make sure the sponsor has waited at least a week before sponsoring someone new.
    assert((current_time - sponsor.last_change) >= WEEK_IN_SECONDS, 'last change too recent')
    # make sure the proposed member address is not already used by a member
    assert(self.members[_address].sponsor == 0, 'address already taken')
    # make sure the handle isn't already used
    assert(not self.handle_taken[_handle], 'handle already taken')

    self.members[_address] = Member(
        {
            sponsor: sponsor_address,
            handle: _handle,
            time_joined: current_time,
            last_change: 0,
        }
    )

    self.handle_taken[_handle] = True
    self.members[sponsor_addr].last_change = current_time
    log.NewMember(sponsor_addr, _address, _handle)


@public
def submit_proposal(_url: string[100], _digest: bytes32, _wallet: address, _value: uint):
    sponsor_address: address = msg.sender
    sponsor: Member = self.members[sponsor_address]
    current_time: timestamp = block.timestamp
    
    # make sure the member is really a member.
    assert(sponsor.sponsor != 0, 'msg.sender is not a member')
    # make sure the member has waited at least a week since their last change.
    assert((current_time - sponsor.last_change) >= WEEK_IN_SECONDS, 'last_change_too_recent')

    proposal_id: bytes32 = keccak256
