import {
  Div,
  Flex,
  Hr,
  Img,
} from 'honorable'

// @ts-ignore
import { ReactComponent as OnboardingTitleOnboarding } from './OnboardingTitle.svg'

function OnboardingTitle() {
  return (
    <Div width="100%">
      <Flex align="flex-end">
        <Img
          src="/logos/plural-logomark-only-white.svg"
          height={22}
          marginRight="xsmall"
          marginBottom={2}
        />
        <Img
          src="/logos/plural-logotype-only-white.svg"
          height={26}
          marginRight="small"
        />
        <OnboardingTitleOnboarding />
      </Flex>
      <Hr
        marginTop="xlarge"
        marginBottom="large"
      />
    </Div>
  )
}

export default OnboardingTitle
