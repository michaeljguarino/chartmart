import { Modal } from '@pluralsh/design-system'
import { DispatchWithoutAction, ReactElement, useMemo, useState } from 'react'
import styled from 'styled-components'

import { Group } from '../../../generated/graphql'
import { GroupBase } from '../../utils/combobox/types'
import CreateGroup from '../../utils/group/CreateGroup'

import InviteUser from './InviteUser'

enum View {
  InviteUser,
  CreateGroup,
}

const InviteUserModal = styled(InviteUserModalUnstyled)((_) => ({}))

function InviteUserModalUnstyled({
  onInvite,
  onClose,
  serviceAccountId,
  oidcProviderId,
  ...props
}): ReactElement {
  const [view, setView] = useState(View.InviteUser)
  const [refetch, setRefetch] = useState<DispatchWithoutAction>()
  const [bindings, setBindings] = useState<Array<GroupBase>>([])

  const header = useMemo(() => {
    switch (view) {
      case View.CreateGroup:
        return 'create group'
      case View.InviteUser:
      default:
        return 'invite user'
    }
  }, [view])

  return (
    <Modal
      open
      onClose={onClose}
      style={{ padding: 0 }}
      size="large"
      header={header}
    >
      <div {...props}>
        {view === View.InviteUser && (
          <InviteUser
            onGroupCreate={() => setView(View.CreateGroup)}
            onInvite={onInvite}
            onCancel={onClose}
            refetch={setRefetch}
            bindings={bindings}
            serviceAccountId={serviceAccountId}
            oidcProviderId={oidcProviderId}
          />
        )}
        {view === View.CreateGroup && (
          <CreateGroup
            onBack={() => setView(View.InviteUser)}
            onCreate={(group: Group) => {
              setBindings((bindings) => [...bindings, group])
              refetch?.()
            }}
          />
        )}
      </div>
    </Modal>
  )
}

export default InviteUserModal
