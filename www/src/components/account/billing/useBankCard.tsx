import {
  Dispatch,
  SetStateAction,
  useCallback,
  useContext,
  useMemo,
  useState,
} from 'react'
import { useMutation } from '@apollo/client'
import { Button, Card } from '@pluralsh/design-system'
import { Div, Flex } from 'honorable'
import { CardElement, useElements, useStripe } from '@stripe/react-stripe-js'
import { capitalize } from 'lodash'

import BillingBankCardContext from '../../../contexts/BillingBankCardContext'

import { GqlError } from '../../utils/Alert'

import { CREATE_CARD_MUTATION, DELETE_CARD_MUTATION } from './queries'

function filledAddress(address) {
  return Object.values(address).every(f => !!f)
}

function useBankCard(setEdit: Dispatch<SetStateAction<boolean>>, address, noCancel = false) {
  const { card, refetch } = useContext(BillingBankCardContext)

  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [createCard, { error: cardError }] = useMutation(CREATE_CARD_MUTATION)
  const [deleteCard] = useMutation(DELETE_CARD_MUTATION)

  const stripe = useStripe()
  const elements = useElements()

  const active = useMemo(() => !address || filledAddress(address), [address])

  const handleSubmit = useCallback(async event => {
    event.preventDefault()

    if (!(stripe && elements)) return

    setLoading(true)

    const { error, token } = await stripe.createToken(elements.getElement(CardElement)!)

    if (error) {
      setError(error.message!)
      setLoading(false)

      return
    }

    try {
      await createCard({
        variables: {
          source: token.id,
          address,
        },
      })

      refetch()
      setEdit(false)
    }
    catch (error) {
      setError((error as any).message)
    }

    setLoading(false)
  }, [stripe, elements, createCard, refetch, setEdit, address])

  const handleDelete = useCallback(async () => {
    if (!card) return

    setLoading(true)

    await deleteCard({
      variables: {
        id: card.id,
      },
    })

    refetch()
    setLoading(false)
  }, [card, deleteCard, refetch])

  const renderEdit = useCallback(() => (
    <form onSubmit={handleSubmit}>
      <Card
        padding="small"
        display="flex"
        alignItems="center"
        gap="small"
      >
        <Flex
          flexGrow={1}
          direction="column"
          justify="center"
          marginTop={-10}
          marginBottom={-10}
        >
          <CardElement options={{ style: { base: { color: '#747B8B' } } }} />
        </Flex>
        <Button
          type="submit"
          disabled={!active || !stripe || !elements}
          loading={loading}
        >
          Add card
        </Button>
        {!noCancel && (
          <Button
            secondary
            type="button"
            onClick={() => setEdit(false)}
          >
            Cancel
          </Button>
        )}
      </Card>
    </form>
  ), [noCancel, stripe, elements, loading, setEdit, handleSubmit, active])

  const renderDisplay = useCallback(() => {
    if (!card) return null

    return (
      <>
        {cardError && (
          <GqlError
            error={cardError}
            header="Failed to add card"
          />
        )}
        <Flex
          align="center"
          gap="small"
        >
          <Card padding="small">
            <Flex
              align="center"
              justify="center"
            >
              {card.brand}
            </Flex>
          </Card>
          <Flex
            direction="column"
            gap="xxxsmall"
          >
            <Div
              fontWeight={600}
              body1
            >
              {capitalize(card.brand)} ending in {card.last4}
            </Div>
            <Div color="text-xlight">
              Expires {card.expMonth.toString().padStart(2, '0')}/{card.expYear}
            </Div>
          </Flex>
          <Div flexGrow={1} />
          <Button
            secondary
            onClick={handleDelete}
            loading={loading}
          >
            Delete
          </Button>
        </Flex>
      </>
    )
  }, [card, loading, cardError, handleDelete])

  return {
    renderEdit,
    renderDisplay,
    error,
  }
}

export default useBankCard
