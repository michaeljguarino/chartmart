import { Flex, Span } from 'honorable'
import { Button } from '@pluralsh/design-system'
import { useNavigate } from 'react-router-dom'

import useOnboarded from '../../../hooks/useOnboarded'
import CalendarIcon from '../../assets/CalendarIcon.svg'

function OverviewStep({ onNext }) {
  const navigate = useNavigate()
  const { fresh: isOnboarding, mutation } = useOnboarded()

  return (
    <Flex
      direction="column"
      gap="xlarge"
    >
      <Flex
        direction="column"
        gap="large"
      >
        <Span body2>Deploy your cluster and applications with Plural in about thirty minutes, then access it via Plural Console. View a demo environment of our Console.</Span>

        <Flex
          direction="column"
          gap="xsmall"
        >
          <Span
            fontWeight="bold"
            body2
          >What to expect:
          </Span>

          <Span>1. Configure your cloud and git credentials.</Span>
          <Span>2. Configure your cluster’s workspace.</Span>
          <Span>3. Create your cloud shell where you can install applications. (25mins deploy wait time)</Span>
        </Flex>
      </Flex>
      <Flex
        gap="medium"
        justify={isOnboarding ? 'space-between' : 'flex-end'}
        borderTop="1px solid border"
        paddingTop="large"
      >
        {isOnboarding && (
          <Button
            data-phid="skip-onboarding"
            secondary
            onClick={() => {
              mutation()
              navigate('/marketplace')
            }}
          >Skip onboarding
          </Button>
        )}
        <Flex
          grow={isOnboarding ? 0 : 1}
          gap="medium"
          justify="space-between"
        >
          <Button
            secondary
            backgroundColor="fill-two"
            startIcon={<img src={CalendarIcon} />}
          >Schedule personalized onboarding
          </Button>
          <Button onClick={onNext}>Get started</Button>
        </Flex>
      </Flex>
    </Flex>
  )
}

export default OverviewStep
