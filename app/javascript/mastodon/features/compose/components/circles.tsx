import { useCallback } from 'react';

import { FormattedMessage, useIntl } from 'react-intl';

import { changeComposeCircle } from '@/mastodon/actions/compose_typed';
import { Button, CaretIcon } from '@/mastodon/components/button/redesign';
import {
  Menu,
  MenuList,
  MenuTrigger,
  MenuItemGroup,
  MenuItemRadio,
} from '@/mastodon/components/menu';
import { Tooltip } from '@/mastodon/components/tooltip';
import type { Circle } from '@/mastodon/models/circle';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';

import { selectComposePrivacy, selectComposeCircleId } from './selectors';

export const ComposeCircle: React.FC<{ className?: string }> = ({
  className,
}) => {
  const privacy = useAppSelector(selectComposePrivacy);
  const circleId = useAppSelector(selectComposeCircleId) ?? '';
  const circle = useAppSelector((state) => state.circles.get(circleId));
  const isEditing = useAppSelector((state) => !!state.compose.get('id'));

  if (privacy !== 'circle') {
    return null;
  }

  if (isEditing) {
    return (
      <div className={className}>
        <Tooltip
          renderTextWhenClosed
          text={
            <FormattedMessage
              id='compose.privacy.editing'
              defaultMessage='Visibility can’t be edited after a post has been published.'
            />
          }
        >
          {({ getTooltipProps, tooltipId }) => (
            <Button
              {...getTooltipProps()}
              size='sm'
              aria-disabled
              aria-describedby={tooltipId}
            >
              <ComposeCircleButtonText circle={circle} />
            </Button>
          )}
        </Tooltip>
      </div>
    );
  }

  return (
    <div className={className}>
      <Menu>
        <MenuTrigger as={Button} size='sm' trailingIcon={CaretIcon}>
          <ComposeCircleButtonText circle={circle} />
        </MenuTrigger>

        <ComposeCircleMenu />
      </Menu>
    </div>
  );
};

export const ComposeCircleButtonText: React.FC<{
  circle: Circle | null | undefined;
}> = ({ circle }) => {
  const intl = useIntl();

  if (!circle) {
    return intl.formatMessage({
      id: 'compose.circle.not_selected',
      defaultMessage: 'Not selected',
    });
  }

  return circle.get('title');
};

const ComposeCircleMenu: React.FC = () => {
  const circleId = useAppSelector(selectComposeCircleId) ?? '';
  const circles = useAppSelector((state) =>
    state.circles
      .toArray()
      .map((circle) => circle[1])
      .filter((circle) => circle !== null),
  );

  const dispatch = useAppDispatch();

  const handleCircleChange = useCallback(
    ({ value }: { value: string }) => {
      if (value !== circleId) {
        dispatch(changeComposeCircle(value));
      }
    },
    [dispatch, circleId],
  );

  return (
    <MenuList placement='bottom-start' offset={4} maxWidth={280}>
      <MenuItemGroup
        label={
          <FormattedMessage id='compose.circle.title' defaultMessage='Circle' />
        }
      >
        {circles.map((circle) => (
          <MenuItemRadio
            key={`circle-${circle.get('id')}`}
            name={`circle-${circle.get('id')}`}
            value={circle.get('id')}
            checked={circle.get('id') === circleId}
            onChange={handleCircleChange}
            keepMenuOpenOnClick
          >
            {circle.get('title')}
          </MenuItemRadio>
        ))}
      </MenuItemGroup>
    </MenuList>
  );
};
