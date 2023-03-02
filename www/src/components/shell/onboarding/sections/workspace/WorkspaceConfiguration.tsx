import {
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react'
import { Flex } from 'honorable'
import { FormField, Input } from '@pluralsh/design-system'

import { OnboardingContext } from '../../context/onboarding'
import { useSetWorkspaceKeys } from '../../context/hooks'
import { IsObjectEmpty } from '../../../../../utils/object'
import { generateString } from '../../../../../utils/string'
import { CloudProvider, WorkspaceProps } from '../../context/types'

type ValidationFieldKey = keyof WorkspaceProps
type Validation = {regex: RegExp, message: string}
type ValidationFn = (provider: CloudProvider) => {regex: RegExp, message: string}
type ValidationField = {[key in ValidationFieldKey]?: Validation | ValidationFn}

const VALIDATOR: ValidationField = {
  clusterName: (provider: CloudProvider) => ({
    regex: provider === CloudProvider.GCP ? /^[a-z][0-9-a-z]{0,11}$/ : /^[a-z][0-9\-a-z]{0,14}$/,
    message: `must be between 1 and ${provider === CloudProvider.GCP ? 12 : 15} characters and may contain hyphenated lowercase alphanumeric string only`,
  }),
  bucketPrefix: {
    regex: /^[a-z][a-z0-9-]{1,61}[a-z0-9]$/,
    message: 'must be between 3 and 64 characters and may contain hyphenated lowercase alphanumeric string only',
  },
}

function WorkspaceConfiguration(): JSX.Element {
  const { workspace, cloud, setValid } = useContext(OnboardingContext)
  const setWorkspaceKeys = useSetWorkspaceKeys()

  const [error, setError] = useState<{[key in ValidationFieldKey]?: string | null}>({})

  const isValid = useMemo(() => !!(workspace?.clusterName && workspace?.bucketPrefix && workspace?.subdomain && IsObjectEmpty(error)), [error, workspace?.bucketPrefix, workspace?.clusterName, workspace?.subdomain])
  const clusterPlaceholder = useMemo(() => `plural-${generateString(5)}`, [])
  const bucketPrefixPlaceholder = useMemo(() => `plural-${generateString(5)}`, [])

  useEffect(() => {
    Object.keys(workspace).forEach(key => {
      const validation = VALIDATOR[key as keyof WorkspaceProps]
      const { regex, message } = (typeof validation === 'function' ? validation(cloud.provider!) : validation) || {}
      const error = regex?.test(workspace?.[key]) ? null : message

      if (!regex || !message) return

      setError(err => ({ ...err, [key]: error }))
    })
  }, [cloud.provider, workspace])

  useEffect(() => setValid(isValid), [isValid, setValid])

  return (
    <Flex
      direction="column"
      gap="medium"
    >
      <FormField
        label="Cluster"
        hint={error.clusterName || 'Give your kubernetes cluster a unique name.'}
        error={!!error.clusterName}
        width="100%"
        required
      >
        <Input
          value={workspace?.clusterName}
          error={!!error.clusterName}
          placeholder={clusterPlaceholder}
          onChange={({ target: { value } }) => setWorkspaceKeys({ clusterName: value })}
        />
      </FormField>

      <FormField
        label="Bucket prefix"
        error={!!error.bucketPrefix}
        hint={error.bucketPrefix || 'A unique prefix to generate bucket names.'}
        width="100%"
        required
      >
        <Input
          value={workspace?.bucketPrefix}
          error={!!error.bucketPrefix}
          placeholder={bucketPrefixPlaceholder}
          onChange={({ target: { value } }) => setWorkspaceKeys({ bucketPrefix: value })}
        />
      </FormField>

      <FormField
        label="Subdomain"
        hint="The domain you'll use for all your applications. Don't worry, you can change your domain later!"
        width="100%"
        required
      >
        <Input
          value={workspace?.subdomain}
          placeholder="my-company"
          onChange={({ target: { value } }) => setWorkspaceKeys({ subdomain: value })}
          suffix=".onplural.sh"
        />
      </FormField>
    </Flex>
  )
}

export { WorkspaceConfiguration }
