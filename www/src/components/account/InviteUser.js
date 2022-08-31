import { Button, Div, Span } from 'honorable'
import {
  Codeline, MailIcon, Modal, ModalActions, ModalHeader, ValidatedInput,
} from 'pluralsh-design-system'
import { useState } from 'react'

import { useMutation } from '@apollo/client'

import { inviteLink } from '../accounts/CreateInvite'
import { CREATE_INVITE } from '../accounts/queries'
import { GqlError } from '../utils/Alert'

export function InviteUser() {
  const [open, setOpen] = useState(false)
  const [email, setEmail] = useState('')
  const [mutation, { loading, data, error }] = useMutation(CREATE_INVITE, {
    variables: { attributes: { email } },
  })

  const invite = data && data.createInvite

  return (
    <>
      <Div>
        <Button
          secondary
          onClick={() => setOpen(true)}
        >Invite user
        </Button>
      </Div>
      <Modal
        open={open}
        onClose={() => setOpen(false)}
        width="40vw"
      >
        <ModalHeader onClose={() => setOpen(false)}>
          INVITE USERS
        </ModalHeader>
        <ValidatedInput
          value={email}
          startIcon={<MailIcon size={15} />}
          onChange={({ target: { value } }) => setEmail(value)}
          label="Email address"
        />
        {error && (
          <GqlError
            error={error}
            header="Failed to invite user"
          />
        )}
        {invite?.secureId && <Codeline marginTop="small">{inviteLink(invite)}</Codeline>}
        {invite && !invite.secureId && <Span>An email was sent to {email} to accept the invite</Span>}
        <ModalActions>
          <Button
            secondary
            onClick={() => setOpen(false)}
          >Cancel
          </Button>
          <Button
            onClick={mutation}
            loading={loading}
            disabled={email.length === 0}
            marginLeft="medium"
          >Invite
          </Button>
        </ModalActions>
      </Modal>
    </>
  )
}
