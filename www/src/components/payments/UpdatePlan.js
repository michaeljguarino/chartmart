import React from 'react'
import { Box, Layer, Text } from 'grommet'
import { useMutation } from 'react-apollo'
import { UPDATE_PLAN } from './queries'
import { updateSubscription } from './utils'
import { ModalHeader } from '../utils/Modal'
import Button from '../utils/Button'

export default function UpdatePlan({plan, repository: {id, installation: {subscription}}, setOpen}) {
  const [mutation, {loading}] = useMutation(UPDATE_PLAN, {
    variables: {subscriptionId: subscription.id, planId: plan.id},
    update: (cache, {data: {updatePlan}}) => {
      updateSubscription(cache, id, updatePlan)
      setOpen(false)
    }
  })
  return (
    <Layer modal position='center' onEsc={() => setOpen(false)}>
      <Box width='40vw'>
        <ModalHeader text={`Switch to the ${plan.name} plan?`} setOpen={setOpen} />
        <Box pad='medium' gap='small'>
          <Text size='small'><i>We will migrate all existing line items to match the new plan for you</i></Text>
          <Box direction='row' align='center' justify='end'>
            <Button loading={loading} pad='small' label='Update' onClick={mutation} />
          </Box>
        </Box>
      </Box>
    </Layer>
  )
}