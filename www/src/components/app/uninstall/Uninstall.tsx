import {
  Button,
  Card,
  Divider,
  Input,
  PageTitle,
} from '@pluralsh/design-system'
import { Div, P } from 'honorable'
import { useState } from 'react'
import { Keyboard } from 'grommet'
import { useMutation } from '@apollo/client'
import styled from 'styled-components'

import { GqlError } from '../../utils/Alert'
import { DELETE_INSTALLATION_MUTATION } from '../../repository/queries'
import { useAppContext } from '../../../contexts/AppContext'
import { AppHeaderActions } from '../AppHeaderActions'

export const StyledInput = styled(Input)(({ theme }) => ({
  backgroundColor: theme.colors['fill-two'],
}))

export function Uninstall() {
  const app = useAppContext()
  const [confirm, setConfirm] = useState('')
  const [mutation, { loading, error }] = useMutation(DELETE_INSTALLATION_MUTATION, {
    variables: { id: app.installation?.id },
    onCompleted: () => window.location.reload(),
  })

  return (
    <Div paddingBottom="large">
      <PageTitle
        heading="Uninstall"
        paddingTop="medium"
      >
        <AppHeaderActions />
      </PageTitle>
      <Card
        display="flex"
        flexDirection="column"
        padding="xlarge"
      >
        <P
          body1
          bold
          marginBottom="xsmall"
        >
          Uninstall application
        </P>
        <P
          body2
          color="text-light"
          marginBottom="xlarge"
        >
          Type the application name, "{app.name}", to confirm uninstall.
          Note that this will uninstall this app from the API
          but not destroy any of its infrastructure.
        </P>
        <Keyboard onEnter={() => {
          if (confirm === app.name) mutation()
        }}
        >
          <StyledInput
            value={confirm}
            onChange={({ target: { value } }) => setConfirm(value)}
            placeholder="Confirm application name"
          />
        </Keyboard>
        {error && (
          <GqlError
            error={error}
            header="Failed to uninstall"
          />
        )}
        <Divider
          backgroundColor="border"
          marginVertical="xlarge"
        />
        <Button
          destructive
          onClick={mutation}
          disabled={confirm !== app.name}
          loading={loading}
          alignSelf="end"
          width="max-content"
        >
          Delete
        </Button>
      </Card>
    </Div>
  )
}
