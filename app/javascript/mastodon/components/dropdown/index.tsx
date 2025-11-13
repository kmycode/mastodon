import { useCallback, useId, useMemo, useRef, useState } from 'react';
import type { ComponentPropsWithoutRef, FC } from 'react';

import { useIntl } from 'react-intl';
import type { MessageDescriptor } from 'react-intl';

import classNames from 'classnames';

import Overlay from 'react-overlays/Overlay';
import type { Placement } from 'react-overlays/esm/usePopper';

import UnfoldMoreIcon from '@/material-icons/400-24px/unfold_more.svg?react';

import type { SelectItem } from '../dropdown_selector';
import { DropdownSelector } from '../dropdown_selector';
import { Icon } from '../icon';

import { matchWidth } from './utils';

interface DropdownProps {
  disabled?: boolean;
  items: SelectItem[];
  onChange: (value: string) => void;
  current: string;
  labelId: string;
  descriptionId?: string;
  emptyText?: MessageDescriptor;
  classPrefix: string;
  placement?: Placement;
  target?: React.RefObject<HTMLElement>;
}

export const Dropdown: FC<
  DropdownProps & Omit<ComponentPropsWithoutRef<'button'>, keyof DropdownProps>
> = ({
  disabled,
  items,
  current,
  onChange,
  labelId,
  descriptionId,
  classPrefix,
  className,
  id,
  placement,
  target,
  ...buttonProps
}) => {
  const intl = useIntl();
  const buttonRef = useRef<HTMLButtonElement>(null);
  const uniqueId = useId();
  const buttonId = id ?? `${uniqueId}-button`;
  const listboxId = `${uniqueId}-listbox`;

  const [open, setOpen] = useState(false);

  const handleToggle = useCallback(() => {
    if (!disabled) {
      setOpen((prevOpen) => {
        buttonRef.current?.focus();
        return !prevOpen;
      });
    }
  }, [disabled]);

  const handleClose = useCallback(() => {
    setOpen(false);
    buttonRef.current?.focus();
  }, []);

  const currentText = useMemo(
    () =>
      items.find((i) => i.value === current)?.text ??
      intl.formatMessage({
        id: 'dropdown.empty',
        defaultMessage: 'Select an option',
      }),
    [current, intl, items],
  );

  return (
    <>
      <button
        type='button'
        {...buttonProps}
        id={buttonId}
        aria-labelledby={`${labelId} ${buttonId}`}
        aria-describedby={descriptionId}
        aria-expanded={open}
        aria-controls={listboxId}
        onClick={handleToggle}
        disabled={disabled}
        className={classNames(
          `${classPrefix}__button`,
          {
            active: open,
            disabled,
          },
          className,
        )}
        ref={buttonRef}
      >
        {currentText}
        <Icon
          id='unfold-icon'
          icon={UnfoldMoreIcon}
          className={`${classPrefix}__icon`}
        />
      </button>

      <Overlay
        show={open}
        offset={[0, 0]}
        placement={placement ?? 'bottom-start'}
        onHide={handleClose}
        flip
        target={target?.current ? target : buttonRef}
        popperConfig={{
          strategy: 'fixed',
          modifiers: [matchWidth],
        }}
      >
        {({ props, placement }) => (
          <div {...props} className={`${classPrefix}__overlay`}>
            <div
              className={classNames(
                'dropdown-animation',
                `${classPrefix}__dropdown`,
                placement,
              )}
              id={listboxId}
            >
              <DropdownSelector
                items={items}
                value={current}
                onClose={handleClose}
                onChange={onChange}
                classNamePrefix={classPrefix}
              />
            </div>
          </div>
        )}
      </Overlay>
    </>
  );
};
