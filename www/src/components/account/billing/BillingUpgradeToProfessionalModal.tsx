import {
  FormEvent,
  useCallback,
  useContext,
  useEffect,
  useState,
} from 'react'
import { Link } from 'react-router-dom'
import { useMutation } from '@apollo/client'
import { Div, Flex } from 'honorable'
import { Button, Card, Modal } from '@pluralsh/design-system'

import PlatformPlansContext from '../../../contexts/PlatformPlansContext'

import { SUBSCRIPTION_QUERY, UPGRADE_TO_PROFESSIONAL_PLAN_MUTATION } from './queries'

import useBankCard from './useBankCard'

import BillingPreview from './BillingPreview'
import BillingError from './BillingError'

type BillingUpgradeToProfessionalModalPropsType = {
  open: boolean
  onClose: () => void
}

function BillingUpgradeToProfessionalModal({
  open,
  onClose: onCloseProp,
}: BillingUpgradeToProfessionalModalPropsType) {
  const { proPlatformPlan, proYearlyPlatformPlan }
    = useContext(PlatformPlansContext)
  const [applyYearlyDiscount, setApplyYearlyDiscount] = useState(false)

  const [upgradeMutation, { loading }] = useMutation(UPGRADE_TO_PROFESSIONAL_PLAN_MUTATION,
    {
      variables: {
        planId: applyYearlyDiscount
          ? proYearlyPlatformPlan.id
          : proPlatformPlan.id,
      },
      refetchQueries: [SUBSCRIPTION_QUERY],
      onCompleted: () => setSuccess(true),
      onError: () => setError(true),
    })

  const [edit, setEdit] = useState(true)
  const [success, setSuccess] = useState(false)
  const [error, setError] = useState(false)

  const {
    error: cardError,
    renderEdit,
    renderDisplay,
    card,
    resetForm,
  } = useBankCard({ setEdit, noCancel: true })

  const onClickUpgrade = useCallback((event: FormEvent) => {
    event.preventDefault()
    if (!card) {
      return
    }

    upgradeMutation()
  },
  [card, upgradeMutation])
  const onClose = useCallback(() => {
    resetForm()
    onCloseProp()
  }, [onCloseProp, resetForm])

  const renderContent = useCallback(() => (
    <>
      <BillingPreview
        noCard
        discountPreview
        yearly={applyYearlyDiscount}
        onChange={setApplyYearlyDiscount}
      />
      <Div
        fontWeight="bold"
        marginTop="large"
        marginBottom="medium"
      >
        Billing information
      </Div>
      <Flex
        flexDirection="column"
        gap="xlarge"
      >
        {edit || !card ? renderEdit() : renderDisplay()}
      </Flex>
      {(error || cardError) && (
        <Card
          marginTop="medium"
          padding="medium"
        >
          <BillingError>{error || cardError}</BillingError>
        </Card>
      )}
      <Flex
        justify="flex-end"
        marginTop="xxlarge"
        gap="small"
      >
        <Button
          secondary
          onClick={() => {
            onClose()
          }}
        >
          Cancel
        </Button>
        <Button
          loading={loading}
          disabled={!card}
          onClick={onClickUpgrade}
        >
          Upgrade
        </Button>
      </Flex>
    </>
  ),
  [
    applyYearlyDiscount,
    edit,
    card,
    renderEdit,
    renderDisplay,
    error,
    cardError,
    onClickUpgrade,
    loading,
    onClose,
  ])

  const renderSuccess = useCallback(() => (
    <>
      <Div>
        Welcome to the Plural Professional plan! You now have access to
        groups, roles, service accounts, and more.
      </Div>
      <Flex
        justify="flex-end"
        marginTop="large"
      >
        <Button
          as={Link}
          to="/marketplace"
        >
          Explore the app
        </Button>
      </Flex>
    </>
  ),
  [])

  useEffect(() => {
    if (!card) return

    setEdit(false)
  }, [card])

  return (
    <Modal
      open={open}
      onClose={onClose}
      header="Upgrade to professional"
      minWidth={512 + 128}
    >
      {success ? renderSuccess() : <>{renderContent()}</>}
    </Modal>
  )
}

export default BillingUpgradeToProfessionalModal
