import {
  Button, Modal, ModalActions, ModalHeader,
} from 'pluralsh-design-system'

import { GqlError } from '../utils/Alert'

export function Confirm({
  open, close, title, error, text, submit, label, loading, destructive,
}) {
  return (
    <Modal
      open={open}
      onClose={close}
      width="512px"
      portal
    >
      <ModalHeader onClose={close}>
        {title || 'Are you sure?'}
      </ModalHeader>
      {error ? (
        <GqlError
          error={error}
          header="Something went wrong"
        />
      ) : text}
      <ModalActions>
        <Button
          secondary
          onClick={close}
        >Cancel
        </Button>
        <Button
          destructive={destructive}
          onClick={submit}
          loading={loading}
          marginLeft="medium"
        >{label || 'Confirm'}
        </Button>
      </ModalActions>
    </Modal>
  )
}
